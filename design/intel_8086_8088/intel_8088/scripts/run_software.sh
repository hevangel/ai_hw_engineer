#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/software"
as --32 -o "$DESIGN_DIR/work/software/startup.o" \
    "$DESIGN_DIR/../intel_8086/tb/software/startup.S"
objcopy -O binary -j .text "$DESIGN_DIR/work/software/startup.o" \
    "$DESIGN_DIR/work/software/startup.bin"
sh "$SCRIPT_DIR/build_runner.sh"
"$DESIGN_DIR/work/verilator/Vintel_8088_chip" --software "$DESIGN_DIR/work/software/startup.bin" \
    > "$DESIGN_DIR/work/software/startup.log" 2>&1
cat "$DESIGN_DIR/work/software/startup.log"
test "$(grep -c '^PASS: Intel 1979 figure 2-63' "$DESIGN_DIR/work/software/startup.log")" = 2
python3 "$SCRIPT_DIR/prepare_software.py"
cd "$DESIGN_DIR/work/software"
"$DESIGN_DIR/work/verilator/Vintel_8088_chip" --debug DEBUG.COM > debug.log 2>&1
cat debug.log
test "$(grep -c '^PASS: unchanged Microsoft MS-DOS 1.25 DEBUG.COM' debug.log)" = 2
