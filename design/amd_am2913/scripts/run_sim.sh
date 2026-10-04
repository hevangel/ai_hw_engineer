#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
mkdir -p "$WORK_DIR"
verilator --cc --exe --build -Wall --top-module tb_top --Mdir "$WORK_DIR/obj" -CFLAGS '-std=c++17 -O2' \
 "$DESIGN_DIR/src/amd_am2913.sv" "$DESIGN_DIR/tb/tb_top.sv" "$DESIGN_DIR/tb/encoder_driver.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vtb_top" > "$WORK_DIR/run.log" 2>&1
cat "$WORK_DIR/run.log"
grep -q 'TEST PASSED:' "$WORK_DIR/run.log"
