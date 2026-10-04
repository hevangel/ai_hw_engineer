#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/math"
mkdir -p "$WORK_DIR"
verilator --lint-only -Wall --top-module tb_math "$DESIGN_DIR/src/amd_am9511_divider.sv" "$DESIGN_DIR/src/amd_am9511_phase_reducer.sv" "$DESIGN_DIR/tb/tb_math.sv" > "$WORK_DIR/lint.log" 2>&1
verilator --cc --exe --build -Wall --top-module tb_math --Mdir "$WORK_DIR/obj" -CFLAGS '-std=c++17 -O2'  "$DESIGN_DIR/src/amd_am9511_divider.sv" "$DESIGN_DIR/src/amd_am9511_phase_reducer.sv" "$DESIGN_DIR/tb/tb_math.sv" "$DESIGN_DIR/tb/math_driver.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vtb_math" > "$WORK_DIR/run.log" 2>&1
cat "$WORK_DIR/run.log"
grep -q 'TEST PASSED:' "$WORK_DIR/run.log"
