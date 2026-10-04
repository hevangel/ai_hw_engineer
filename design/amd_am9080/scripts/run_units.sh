#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/units"
mkdir -p "$WORK_DIR"
gcc -std=c99 -O2 "$SCRIPT_DIR/oracle_units.c" \
    "$DESIGN_DIR/references/superzazu/i8080.c" -o "$WORK_DIR/oracle_units"
"$WORK_DIR/oracle_units" "$WORK_DIR/units.bundle"
verilator --lint-only -Wall --timing --top-module tb_software \
    "$DESIGN_DIR/src/amd_am9080_alu.sv" "$DESIGN_DIR/src/amd_am9080.sv" "$DESIGN_DIR/tb/tb_software.sv"
verilator --binary --timing --top-module tb_software -j 4 --Mdir "$WORK_DIR/obj" -o am9080_units \
    "$DESIGN_DIR/src/amd_am9080_alu.sv" "$DESIGN_DIR/src/amd_am9080.sv" "$DESIGN_DIR/tb/tb_software.sv" \
    > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/am9080_units" "+UNITFILE=$WORK_DIR/units.bundle" > "$WORK_DIR/units.log" 2>&1
cat "$WORK_DIR/units.log"
if grep -Eq '%Fatal|%Error|Assertion failed' "$WORK_DIR/units.log"; then exit 1; fi
grep -q 'TEST PASSED: 7808 cases, all 244 documented opcodes' "$WORK_DIR/units.log"
