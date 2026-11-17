#!/bin/sh
# Build the IBM PC AT 5170 with a display adapter in a slot under Verilator,
# run the unchanged REV1 BIOS and the card's own BIOS ROM, and check the run
# five ways:
#   - it stops exactly where scripts/expected_stop_<card>.txt says;
#   - the picture on the card's monitor connector reads, with the ROM's own
#     font, as the text in tb/expected_screen_<card>.txt;
#   - the 8042 on the board matches the UPI-42 reference model;
#   - the MC146818 on the board matches its reference model;
#   - every executed 80286 instruction, in the system BIOS and in the
#     adapter BIOS, matches Unicorn.
#
# Usage: scripts/run_post_card.sh ega|vga /path/to/atbios.bin
#   ega  IBM Enhanced Graphics Adapter, src/ibm_pc_at_5170_ega.sv
#   vga  IBM PS/2 Display Adapter (VGA), src/ibm_pc_at_5170_vga.sv
# Output: $IBM_PC_AT_WORK_DIR (default system/ibm_pc_at_5170/work)/post_<card>
# The card's ROM is fetched and hash-checked by the card design's
# scripts/get_rom.py; the 8042 firmware is rebuilt and hash-checked as in
# run_post.sh. The MC146818 starts from tb/cmos_ega.hex (equipment byte:
# the display has its own BIOS), for either card.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$SYS_DIR/../.." && pwd)
WORK_DIR=${IBM_PC_AT_WORK_DIR:-$SYS_DIR/work}
. "$SCRIPT_DIR/sources.sh"
if [ "$#" -ne 2 ]; then
    echo "usage: $0 ega|vga /path/to/atbios.bin" >&2
    exit 2
fi
CARD=$1
case $CARD in
    ega) CARD_DIR=$EGA_DIR; CARD_RTL=$EGA_RTL; CARD_BIN=ega_u44.bin; CARD_HEX=ega_u44_chip.hex
         CARD_DEFINE=AT_EGA; CARD_PARAM=EGA_ROM_FILE; CARD_NAME="EGA ROM: fetch IBM 6277356" ;;
    vga) CARD_DIR=$VGA_DIR; CARD_RTL=$VGA_RTL; CARD_BIN=vga_rom.bin; CARD_HEX=vga_rom.hex
         CARD_DEFINE=AT_VGA; CARD_PARAM=VGA_ROM_FILE; CARD_NAME="VGA ROM: fetch the IBM PS/2 Display Adapter BIOS" ;;
    *) echo "unknown card $CARD" >&2; exit 2 ;;
esac
TOP=ibm_pc_at_5170_$CARD
OUT_DIR=$WORK_DIR/post_$CARD
ROM=$(CDPATH= cd -- "$(dirname -- "$2")" && pwd)/$(basename -- "$2")
printf '%s  %s\n' 74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f "$ROM" | sha256sum -c -
mkdir -p "$OUT_DIR"
if [ ! -f "$WORK_DIR/oracle/unicorn/__init__.py" ]; then
    python3 -m pip install --quiet --target "$WORK_DIR/oracle" unicorn==2.1.4
fi

echo "== 8042 firmware: rebuild IBM 1503033 and verify its hash"
KBC_ROM=$(python3 "$KBC_DIR/scripts/rebuild_1503033.py" --work "$WORK_DIR/kbc")
od -An -v -tx1 -w1 "$KBC_ROM" | tr -d ' ' > "$OUT_DIR/kbc_1503033.hex"
[ "$(wc -l < "$OUT_DIR/kbc_1503033.hex")" -eq 2048 ]

echo "== $CARD_NAME and verify its hashes"
python3 "$CARD_DIR/scripts/get_rom.py" "$WORK_DIR/$CARD" > "$OUT_DIR/card_rom.log"
CARD_ROM=$WORK_DIR/$CARD/firmware/$CARD_BIN
CARD_ROM_HEX=$WORK_DIR/$CARD/firmware/$CARD_HEX
[ -f "$CARD_ROM" ] && [ -f "$CARD_ROM_HEX" ]

# shellcheck disable=SC2086
sha256sum $BOARD_RTL $CHANNEL_RTL $CARD_RTL "$SYS_DIR/src/$TOP.sv" \
    "$SYS_DIR/tb/${TOP}_tb.sv" "$SYS_DIR/tb/post_runner.cpp" \
    "$SCRIPT_DIR/run_post_card.sh" "$SCRIPT_DIR/sources.sh" "$SCRIPT_DIR/check_post_trace.py" \
    "$SCRIPT_DIR/check_kbc_log.py" "$SCRIPT_DIR/check_rtc_log.py" "$SCRIPT_DIR/check_frame.py" \
    "$SCRIPT_DIR/expected_stop_$CARD.txt" "$SYS_DIR/tb/expected_screen_$CARD.txt" \
    "$RTC_DIR/scripts/mc146818_model.py" \
    "$CPU_DIR/scripts/bios_replay.py" "$CPU_DIR/scripts/generate_firmware_trace.py" \
    "$KBC_DIR/scripts/upi42_iss.py" "$SYS_DIR/tb/cmos_ega.hex" "$KBC_ROM" "$CARD_ROM" "$ROM" \
    > "$OUT_DIR/inputs.sha256"
{ verilator --version; g++ --version | head -n 1; python3 --version; } > "$OUT_DIR/toolchain.txt"

echo "== lint: $TOP"
# shellcheck disable=SC2086
verilator --lint-only -Wall -Wno-SYNCASYNCNET --timescale-override 1ns/1ps \
    --top-module $TOP $BOARD_RTL $CHANNEL_RTL $CARD_RTL "$SYS_DIR/src/$TOP.sv"

echo "== build"
# shellcheck disable=SC2086
if ! verilator --cc --exe --build -j 4 -O3 -Wall -Wno-SYNCASYNCNET --timescale-override 1ns/1ps \
    -CFLAGS "-D$CARD_DEFINE" \
    "-GKBC_ROM_FILE=\"$OUT_DIR/kbc_1503033.hex\"" \
    "-GRTC_NVRAM_FILE=\"$SYS_DIR/tb/cmos_ega.hex\"" \
    "-G$CARD_PARAM=\"$CARD_ROM_HEX\"" \
    --top-module ${TOP}_tb --Mdir "$OUT_DIR/obj" $BOARD_RTL $CHANNEL_RTL $CARD_RTL \
    "$SYS_DIR/src/$TOP.sv" "$SYS_DIR/tb/${TOP}_tb.sv" \
    "$SYS_DIR/tb/post_runner.cpp" > "$OUT_DIR/build.log" 2>&1; then
    cat "$OUT_DIR/build.log" >&2
    exit 1
fi

EXPECTED=$(grep -v '^#' "$SCRIPT_DIR/expected_stop_$CARD.txt")
STOP_ADDR=$(echo "$EXPECTED" | sed -n 's/.* after=\([0-9A-F]*\) .*/\1/p')
STOP_AT=$(echo "$EXPECTED" | sed -n 's/.* at=\([0-9A-F]*:[0-9A-F]*\).*/\1/p')
echo "== run (processor ready with no added wait states; the 8254 clock is OSC/12)"
"$OUT_DIR/obj/V${TOP}_tb" "$ROM" "$OUT_DIR/trace.txt" 0 1 \
    "$OUT_DIR/kbc.txt" "$OUT_DIR/rtc.txt" "--stop-at=$STOP_ADDR" "--frame=$OUT_DIR/frame.ppm" \
    | tee "$OUT_DIR/run.log"
stop=$(sed -n 's/^STOP \(kind=[^ ]*\) \(at=[^ ]*\) post=\([0-9A-F]*\).*/\1 after='"$STOP_ADDR"' \2 post=\3/p' "$OUT_DIR/run.log")
if [ "$stop" != "$EXPECTED" ]; then
    echo "FAIL: stopped at '$stop', expected '$EXPECTED'" >&2
    exit 1
fi
status=0
echo "== screen"
python3 "$SCRIPT_DIR/check_frame.py" "$CARD_ROM" "$OUT_DIR/frame.ppm" \
    "$SYS_DIR/tb/expected_screen_$CARD.txt" "$OUT_DIR/frame.png" || status=1
echo "== 8042 reference model"
python3 "$SCRIPT_DIR/check_kbc_log.py" "$KBC_ROM" "$OUT_DIR/kbc.txt" || status=1
echo "== MC146818 reference model"
python3 "$SCRIPT_DIR/check_rtc_log.py" "$SYS_DIR/tb/cmos_ega.hex" "$OUT_DIR/rtc.txt" || status=1
echo "== 80286 oracle (system BIOS and adapter BIOS)"
PYTHONPATH="$WORK_DIR/oracle:$CPU_DIR/scripts${PYTHONPATH:+:$PYTHONPATH}" \
    python3 "$SCRIPT_DIR/check_post_trace.py" "$ROM" "$OUT_DIR/trace.txt" "$STOP_AT" \
    "C0000:$CARD_ROM" || status=1
sha256sum -c "$OUT_DIR/inputs.sha256" > "$OUT_DIR/source_verification.log"
[ "$status" -eq 0 ] && echo "PASS: AT with $CARD stopped at: $EXPECTED"
exit "$status"
