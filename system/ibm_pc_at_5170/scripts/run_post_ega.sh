#!/bin/sh
# Build the IBM PC AT 5170 with an IBM Enhanced Graphics Adapter in a slot
# (src/ibm_pc_at_5170_ega.sv) under Verilator, run the unchanged REV1 BIOS
# and the card's own BIOS ROM, and check the run five ways:
#   - it stops exactly where scripts/expected_stop_ega.txt says;
#   - the picture on the card's monitor connector reads, with the ROM's own
#     font, as the text in tb/expected_screen_ega.txt;
#   - the 8042 on the board matches the UPI-42 reference model;
#   - the MC146818 on the board matches its reference model;
#   - every executed 80286 instruction, in the system BIOS and in the
#     adapter BIOS, matches Unicorn.
#
# Usage: scripts/run_post_ega.sh /path/to/atbios.bin
# Output: $IBM_PC_AT_WORK_DIR (default system/ibm_pc_at_5170/work)/post_ega
# The EGA ROM (IBM 6277356) is fetched and hash-checked by
# design/ibm_ega/scripts/get_rom.py; the 8042 firmware is rebuilt and
# hash-checked as in run_post.sh. The MC146818 starts from tb/cmos_ega.hex.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$SYS_DIR/../.." && pwd)
WORK_DIR=${IBM_PC_AT_WORK_DIR:-$SYS_DIR/work}
OUT_DIR=$WORK_DIR/post_ega
. "$SCRIPT_DIR/sources.sh"
if [ "$#" -ne 1 ]; then
    echo "usage: $0 /path/to/atbios.bin" >&2
    exit 2
fi
ROM=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
printf '%s  %s\n' 74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f "$ROM" | sha256sum -c -
mkdir -p "$OUT_DIR"
if [ ! -f "$WORK_DIR/oracle/unicorn/__init__.py" ]; then
    python3 -m pip install --quiet --target "$WORK_DIR/oracle" unicorn==2.1.4
fi

echo "== 8042 firmware: rebuild IBM 1503033 and verify its hash"
KBC_ROM=$(python3 "$KBC_DIR/scripts/rebuild_1503033.py" --work "$WORK_DIR/kbc")
od -An -v -tx1 -w1 "$KBC_ROM" | tr -d ' ' > "$OUT_DIR/kbc_1503033.hex"
[ "$(wc -l < "$OUT_DIR/kbc_1503033.hex")" -eq 2048 ]

echo "== EGA ROM: fetch IBM 6277356 and verify its hashes"
python3 "$EGA_DIR/scripts/get_rom.py" "$WORK_DIR/ega" > "$OUT_DIR/ega_rom.log"
EGA_ROM=$WORK_DIR/ega/firmware/ega_u44.bin
EGA_HEX=$WORK_DIR/ega/firmware/ega_u44_chip.hex
[ -f "$EGA_ROM" ] && [ -f "$EGA_HEX" ]

# shellcheck disable=SC2086
sha256sum $BOARD_RTL $CHANNEL_RTL $EGA_RTL "$SYS_DIR/src/ibm_pc_at_5170_ega.sv" \
    "$SYS_DIR/tb/ibm_pc_at_5170_ega_tb.sv" "$SYS_DIR/tb/post_runner.cpp" \
    "$SCRIPT_DIR/run_post_ega.sh" "$SCRIPT_DIR/sources.sh" "$SCRIPT_DIR/check_post_trace.py" \
    "$SCRIPT_DIR/check_kbc_log.py" "$SCRIPT_DIR/check_rtc_log.py" "$SCRIPT_DIR/check_frame.py" \
    "$SCRIPT_DIR/expected_stop_ega.txt" "$SYS_DIR/tb/expected_screen_ega.txt" \
    "$RTC_DIR/scripts/mc146818_model.py" \
    "$CPU_DIR/scripts/bios_replay.py" "$CPU_DIR/scripts/generate_firmware_trace.py" \
    "$KBC_DIR/scripts/upi42_iss.py" "$SYS_DIR/tb/cmos_ega.hex" "$KBC_ROM" "$EGA_ROM" "$ROM" \
    > "$OUT_DIR/inputs.sha256"
{ verilator --version; g++ --version | head -n 1; python3 --version; } > "$OUT_DIR/toolchain.txt"

echo "== lint: ibm_pc_at_5170_ega"
# shellcheck disable=SC2086
verilator --lint-only -Wall -Wno-SYNCASYNCNET --timescale-override 1ns/1ps \
    --top-module ibm_pc_at_5170_ega $BOARD_RTL $CHANNEL_RTL $EGA_RTL "$SYS_DIR/src/ibm_pc_at_5170_ega.sv"

echo "== build"
# shellcheck disable=SC2086
if ! verilator --cc --exe --build -j 4 -O3 -Wall -Wno-SYNCASYNCNET --timescale-override 1ns/1ps \
    -CFLAGS -DAT_EGA \
    "-GKBC_ROM_FILE=\"$OUT_DIR/kbc_1503033.hex\"" \
    "-GRTC_NVRAM_FILE=\"$SYS_DIR/tb/cmos_ega.hex\"" \
    "-GEGA_ROM_FILE=\"$EGA_HEX\"" \
    --top-module ibm_pc_at_5170_ega_tb --Mdir "$OUT_DIR/obj" $BOARD_RTL $CHANNEL_RTL $EGA_RTL \
    "$SYS_DIR/src/ibm_pc_at_5170_ega.sv" "$SYS_DIR/tb/ibm_pc_at_5170_ega_tb.sv" \
    "$SYS_DIR/tb/post_runner.cpp" > "$OUT_DIR/build.log" 2>&1; then
    cat "$OUT_DIR/build.log" >&2
    exit 1
fi

EXPECTED=$(grep -v '^#' "$SCRIPT_DIR/expected_stop_ega.txt")
STOP_ADDR=$(echo "$EXPECTED" | sed -n 's/.* after=\([0-9A-F]*\) .*/\1/p')
STOP_AT=$(echo "$EXPECTED" | sed -n 's/.* at=\([0-9A-F]*:[0-9A-F]*\).*/\1/p')
echo "== run (processor ready with no added wait states; the 8254 clock is OSC/12)"
"$OUT_DIR/obj/Vibm_pc_at_5170_ega_tb" "$ROM" "$OUT_DIR/trace.txt" 0 1 \
    "$OUT_DIR/kbc.txt" "$OUT_DIR/rtc.txt" "--stop-at=$STOP_ADDR" "--frame=$OUT_DIR/frame.ppm" \
    | tee "$OUT_DIR/run.log"
stop=$(sed -n 's/^STOP \(kind=[^ ]*\) \(at=[^ ]*\) post=\([0-9A-F]*\).*/\1 after='"$STOP_ADDR"' \2 post=\3/p' "$OUT_DIR/run.log")
if [ "$stop" != "$EXPECTED" ]; then
    echo "FAIL: stopped at '$stop', expected '$EXPECTED'" >&2
    exit 1
fi
status=0
echo "== screen"
python3 "$SCRIPT_DIR/check_frame.py" "$EGA_ROM" "$OUT_DIR/frame.ppm" \
    "$SYS_DIR/tb/expected_screen_ega.txt" "$OUT_DIR/frame.png" || status=1
echo "== 8042 reference model"
python3 "$SCRIPT_DIR/check_kbc_log.py" "$KBC_ROM" "$OUT_DIR/kbc.txt" || status=1
echo "== MC146818 reference model"
python3 "$SCRIPT_DIR/check_rtc_log.py" "$SYS_DIR/tb/cmos_ega.hex" "$OUT_DIR/rtc.txt" || status=1
echo "== 80286 oracle (system BIOS and EGA BIOS)"
PYTHONPATH="$WORK_DIR/oracle:$CPU_DIR/scripts${PYTHONPATH:+:$PYTHONPATH}" \
    python3 "$SCRIPT_DIR/check_post_trace.py" "$ROM" "$OUT_DIR/trace.txt" "$STOP_AT" \
    "C0000:$EGA_ROM" || status=1
sha256sum -c "$OUT_DIR/inputs.sha256" > "$OUT_DIR/source_verification.log"
[ "$status" -eq 0 ] && echo "PASS: AT with EGA stopped at: $EXPECTED"
exit "$status"
