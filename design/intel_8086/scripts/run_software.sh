#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/software"
as --32 -o "$DESIGN_DIR/work/software/startup.o" "$DESIGN_DIR/tb/software/startup.S"
objcopy -O binary -j .text "$DESIGN_DIR/work/software/startup.o" "$DESIGN_DIR/work/software/startup.bin"
sh "$SCRIPT_DIR/build_runner.sh"
"$DESIGN_DIR/work/verilator/Vintel_8086" --software "$DESIGN_DIR/work/software/startup.bin" \
    > "$DESIGN_DIR/work/software/startup.log" 2>&1
cat "$DESIGN_DIR/work/software/startup.log"
grep -q '^PASS: Intel 1979 figure 2-63' "$DESIGN_DIR/work/software/startup.log"
