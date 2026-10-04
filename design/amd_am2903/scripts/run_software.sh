#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/software"
mkdir -p "$WORK_DIR"
verilator --cc --exe --build -Wall -fno-dfg --top-module tb_multiply --Mdir "$WORK_DIR/obj" -CFLAGS '-std=c++17 -O2' \
 "$DESIGN_DIR/src/amd_am2903_datapath.sv" "$DESIGN_DIR/src/amd_am2903.sv" "$DESIGN_DIR/../amd_am2910/src/amd_am2910.sv" \
 "$DESIGN_DIR/tb/tb_multiply.sv" "$DESIGN_DIR/tb/multiply_driver.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vtb_multiply" "$DESIGN_DIR/references/multiply.csv" > "$WORK_DIR/run.log" 2>&1
cat "$WORK_DIR/run.log"
grep -q 'TEST PASSED:' "$WORK_DIR/run.log"
