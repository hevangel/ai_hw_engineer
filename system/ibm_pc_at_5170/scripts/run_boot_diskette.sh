#!/bin/sh
# Boot the IBM PC AT 5170 (VGA machine, diskette adapter fitted) from a
# script-built 1.2 MB diskette and check the run:
#   - POST shows no 601 (and no other error than 301, the missing keyboard):
#     the screen text is tb/expected_screen_boot.txt;
#   - the BIOS's bootstrap loader read the boot sector through the
#     controller and DMA (D records at 7C00h-7DFFh equal the image);
#   - the boot program read the whole test file (multi-sector reads across
#     the head boundary, over 79 cylinders), checked its sum and printed
#     READ OK, WRITE OK and PASS (on the screen);
#   - the sector it wrote is in the image the runner wrote back;
#   - the adapter and controller traffic matches the independent model
#     (scripts/check_fdc_log.py), including the written-back image;
#   - the 8042 and the MC146818 match their reference models;
#   - every 80286 instruction of the whole run matches Unicorn, with the DMA
#     memory transfers applied as device inputs (D records).
#
# The keyboard: no keyboard device is attached. POST reports 301 and waits
# for F1 at checkpoint 3Fh; the runner's bench stimulus (--f1-at-post=3F,
# see tb/post_runner.cpp F1Stimulus) then sends F1's make and break codes on
# the keyboard connector's clock and data lines with the keyboard protocol.
#
# Usage: scripts/run_boot_diskette.sh /path/to/atbios.bin [--ext-kb=1024]
#   --ext-kb=1024  fit 1024 KB of expansion RAM (2 MB machine) and start the
#                  MC146818 from tb/cmos_vga_2mb.hex
# Output: $IBM_PC_AT_WORK_DIR (default system/ibm_pc_at_5170/work)/boot[_2mb]
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$SYS_DIR/../.." && pwd)
WORK_DIR=${IBM_PC_AT_WORK_DIR:-$SYS_DIR/work}
. "$SCRIPT_DIR/sources.sh"
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "usage: $0 /path/to/atbios.bin [--ext-kb=1024]" >&2
    exit 2
fi
EXT_KB=0
CMOS=$SYS_DIR/tb/cmos_ega.hex
OUT_DIR=$WORK_DIR/boot
if [ "$#" -eq 2 ]; then
    [ "$2" = "--ext-kb=1024" ] || { echo "only --ext-kb=1024 is supported" >&2; exit 2; }
    EXT_KB=1024
    CMOS=$SYS_DIR/tb/cmos_vga_2mb.hex
    OUT_DIR=$WORK_DIR/boot_2mb
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
echo "== VGA ROM: fetch the IBM PS/2 Display Adapter BIOS and verify its hashes"
python3 "$VGA_DIR/scripts/get_rom.py" "$WORK_DIR/vga" > "$OUT_DIR/card_rom.log"
CARD_ROM=$WORK_DIR/vga/firmware/vga_rom.bin
CARD_ROM_HEX=$WORK_DIR/vga/firmware/vga_rom.hex
echo "== test diskettes (scripts/make_test_diskette.py)"
python3 "$SCRIPT_DIR/make_test_diskette.py" "$OUT_DIR/media"
cp "$OUT_DIR/media/boot_1200.img" "$OUT_DIR/fda.img"

# shellcheck disable=SC2086
sha256sum $BOARD_RTL $CHANNEL_RTL $VGA_RTL "$SYS_DIR/src/ibm_pc_at_5170_vga.sv" \
    "$SYS_DIR/tb/ibm_pc_at_5170_vga_tb.sv" "$SYS_DIR/tb/post_runner.cpp" \
    "$SYS_DIR/tb/at_diskette_media.hpp" "$SYS_DIR/tb/boot_diskette.S" \
    "$SCRIPT_DIR/run_boot_diskette.sh" "$SCRIPT_DIR/make_test_diskette.py" "$SCRIPT_DIR/sources.sh" \
    "$SCRIPT_DIR/check_post_trace.py" "$SCRIPT_DIR/check_kbc_log.py" "$SCRIPT_DIR/check_rtc_log.py" \
    "$SCRIPT_DIR/check_frame.py" "$SCRIPT_DIR/check_fdc_log.py" "$SYS_DIR/tb/expected_screen_boot.txt" \
    "$RTC_DIR/scripts/mc146818_model.py" "$CPU_DIR/scripts/bios_replay.py" \
    "$CPU_DIR/scripts/generate_firmware_trace.py" "$KBC_DIR/scripts/upi42_iss.py" "$CMOS" \
    "$KBC_ROM" "$CARD_ROM" "$ROM" > "$OUT_DIR/inputs.sha256"
{ verilator --version; g++ --version | head -n 1; python3 --version; as --version | head -n 1; } \
    > "$OUT_DIR/toolchain.txt"

echo "== lint: ibm_pc_at_5170_vga"
# shellcheck disable=SC2086
verilator --lint-only -Wall -Wno-SYNCASYNCNET --timescale-override 1ns/1ps \
    --top-module ibm_pc_at_5170_vga $BOARD_RTL $CHANNEL_RTL $VGA_RTL "$SYS_DIR/src/ibm_pc_at_5170_vga.sv"
echo "== build"
# shellcheck disable=SC2086
if ! verilator --cc --exe --build -j 4 -O3 -Wall -Wno-SYNCASYNCNET --timescale-override 1ns/1ps \
    -CFLAGS "-DAT_VGA" \
    "-GKBC_ROM_FILE=\"$OUT_DIR/kbc_1503033.hex\"" "-GRTC_NVRAM_FILE=\"$CMOS\"" \
    "-GVGA_ROM_FILE=\"$CARD_ROM_HEX\"" \
    --top-module ibm_pc_at_5170_vga_tb --Mdir "$OUT_DIR/obj" $BOARD_RTL $CHANNEL_RTL $VGA_RTL \
    "$SYS_DIR/src/ibm_pc_at_5170_vga.sv" "$SYS_DIR/tb/ibm_pc_at_5170_vga_tb.sv" \
    "$SYS_DIR/tb/post_runner.cpp" > "$OUT_DIR/build.log" 2>&1; then
    cat "$OUT_DIR/build.log" >&2
    exit 1
fi

echo "== run: power on, POST, F1, boot from drive A, boot program (halts when done)"
"$OUT_DIR/obj/Vibm_pc_at_5170_vga_tb" "$ROM" "$OUT_DIR/trace.txt" 0 1 \
    "$OUT_DIR/kbc.txt" "$OUT_DIR/rtc.txt" "--fda=$OUT_DIR/fda.img" --write-back --f1-at-post=3F \
    "--ext-kb=$EXT_KB" "--frame=$OUT_DIR/frame.ppm" --max-cycles=4000000000 | tee "$OUT_DIR/run.log"
stop=$(sed -n 's/^STOP kind=\([^ ]*\) at=\([0-9A-F]*\):\([0-9A-F]*\) .*/\1 \2 \3/p' "$OUT_DIR/run.log")
set -- $stop
if [ "${1:-}" != halt ] || [ "${2:-}" != 0000 ]; then
    echo "FAIL: the run did not end in the boot program's halt: $stop" >&2
    exit 1
fi
STOP_AT=$2:$3
status=0
echo "== screen"
python3 "$SCRIPT_DIR/check_frame.py" "$CARD_ROM" "$OUT_DIR/frame.ppm" \
    "$SYS_DIR/tb/expected_screen_boot.txt" "$OUT_DIR/frame.png" || status=1
echo "== boot sector read through the controller and DMA"
python3 - "$OUT_DIR/trace.txt" "$OUT_DIR/media/boot_1200.img" <<'EOF' || status=1
import sys
image = open(sys.argv[2], 'rb').read()
got = {}
with open(sys.argv[1]) as trace:
    for line in trace:
        if line[0] == 'D':
            _, a, v, w = line.split()
            a = int(a, 16)
            if w == '1' and 0x7c00 <= a < 0x7e00 and a not in got:
                got[a] = int(v, 16)
if len(got) != 512 or any(got[0x7c00 + i] != image[i] for i in range(512)):
    raise SystemExit(f'FAIL: DMA wrote {len(got)} of the 512 boot-sector bytes at 7C00h, or wrong values')
print('PASS: the boot sector reached 0000:7C00 by DMA, 512 bytes equal to the image')
EOF
echo "== written sector in the written-back image"
python3 - "$OUT_DIR/fda.img" "$OUT_DIR/media/boot_1200.json" "$OUT_DIR/media/boot_1200.img" <<'EOF' || status=1
import json, sys
final = open(sys.argv[1], 'rb').read()
params = json.load(open(sys.argv[2]))
before = open(sys.argv[3], 'rb').read()
lba = params['write_lba']
want = bytes.fromhex(params['write_pattern'])
if final[lba * 512:(lba + 1) * 512] != want:
    raise SystemExit(f'FAIL: sector {lba} of the written-back image is not the pattern')
if final[:lba * 512] != before[:lba * 512]:
    raise SystemExit('FAIL: the written-back image differs outside the written sector')
print(f'PASS: LBA {lba} holds the pattern and no other sector changed')
EOF
echo "== diskette adapter and controller against the model"
python3 "$SCRIPT_DIR/check_fdc_log.py" "$OUT_DIR/trace.txt" "--fda=$OUT_DIR/media/boot_1200.img" \
    "--final-a=$OUT_DIR/fda.img" || status=1
echo "== 8042 reference model"
python3 "$SCRIPT_DIR/check_kbc_log.py" "$KBC_ROM" "$OUT_DIR/kbc.txt" || status=1
echo "== MC146818 reference model"
python3 "$SCRIPT_DIR/check_rtc_log.py" "$CMOS" "$OUT_DIR/rtc.txt" || status=1
echo "== 80286 oracle (system BIOS, VGA BIOS and boot program)"
PYTHONPATH="$WORK_DIR/oracle:$CPU_DIR/scripts${PYTHONPATH:+:$PYTHONPATH}" \
    python3 "$SCRIPT_DIR/check_post_trace.py" "$ROM" "$OUT_DIR/trace.txt" "$STOP_AT" \
    "C0000:$CARD_ROM" "--ext-kb=$EXT_KB" --boot || status=1
sha256sum -c "$OUT_DIR/inputs.sha256" > "$OUT_DIR/source_verification.log"
[ "$status" -eq 0 ] && echo "PASS: AT booted from the 1.2 MB diskette; boot program passed"
exit "$status"
