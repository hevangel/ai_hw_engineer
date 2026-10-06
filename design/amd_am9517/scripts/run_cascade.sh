#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK_DIR="$HERE/work/cascade"
mkdir -p "$WORK_DIR"
verilator --lint-only -Wall --top-module tb_cascade "$HERE/src/amd_am9517.sv" "$HERE/tb/tb_cascade.sv" > "$WORK_DIR/lint.log" 2>&1
verilator --cc --exe --build -Wall --top-module tb_cascade --Mdir "$WORK_DIR/obj" -CFLAGS '-std=c++17 -O2'  "$HERE/src/amd_am9517.sv" "$HERE/tb/tb_cascade.sv" "$HERE/tb/cascade_driver.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vtb_cascade" > "$WORK_DIR/run.log" 2>&1
cat "$WORK_DIR/run.log"
grep -q 'TEST PASSED:' "$WORK_DIR/run.log"
