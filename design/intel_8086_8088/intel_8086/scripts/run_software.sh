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
python3 "$SCRIPT_DIR/prepare_software.py"
cd "$DESIGN_DIR/work/software"
"$DESIGN_DIR/work/verilator/Vintel_8086" --debug DEBUG.COM > debug.log 2>&1
cat debug.log
grep -q '^PASS: unchanged Microsoft MS-DOS 1.25 DEBUG.COM' debug.log

# Run the same unchanged application through both physical bus interfaces,
# without requiring the separately downloaded instruction-vector corpus.
mkdir -p "$DESIGN_DIR/work/native"
verilator --cc --exe --build -j 4 --assert --public-flat-rw -Wall \
    --top-module intel_8086_chip --Mdir "$DESIGN_DIR/work/native" \
    "$DESIGN_DIR/src/"*.sv "$DESIGN_DIR/tb/tb_native.cpp" \
    > "$DESIGN_DIR/work/native/build.log" 2>&1
"$DESIGN_DIR/work/native/Vintel_8086_chip" --debug DEBUG.COM > native-debug.log 2>&1
cat native-debug.log
test "$(grep -c '^PASS: unchanged Microsoft' native-debug.log)" = 2
