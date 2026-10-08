#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
sh "$SCRIPT_DIR/check_oracle.sh"
WORK_DIR="$DESIGN_DIR/work/alu"
mkdir -p "$WORK_DIR"
verilator --cc --exe --build -Wall --top-module intel_8080_alu -j 4 \
    --Mdir "$WORK_DIR/obj" -o i8080_alu \
    "$DESIGN_DIR/src/intel_8080_alu.sv" "$DESIGN_DIR/tb/alu_driver.cpp" \
    > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/i8080_alu" > "$WORK_DIR/alu.log" 2>&1
cat "$WORK_DIR/alu.log"
grep -q 'TEST PASSED: 16842752 independent-oracle ALU/flag checks; 0 failures' "$WORK_DIR/alu.log"
