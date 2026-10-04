#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
mkdir -p "$WORK_DIR"
verilator --binary --timing -Wall --top-module tb_top --Mdir "$WORK_DIR/obj" \
    "$DESIGN_DIR/src/amd_am2902.sv" "$DESIGN_DIR/../amd_am2901/src/amd_am2901_alu.sv" \
    "$DESIGN_DIR/tb/tb_top.sv" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vtb_top" > "$WORK_DIR/run.log" 2>&1
cat "$WORK_DIR/run.log"
grep -q 'TEST PASSED:' "$WORK_DIR/run.log"
if grep -Eq '%Fatal|%Error|Assertion failed' "$WORK_DIR/run.log"; then exit 1; fi
