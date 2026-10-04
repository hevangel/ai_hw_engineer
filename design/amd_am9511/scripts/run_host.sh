#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/host"
mkdir -p "$WORK_DIR"
python3 "$SCRIPT_DIR/generate_commands.py" --check
python3 "$SCRIPT_DIR/generate_derived_constants.py" --check
verilator --lint-only -Wall -I"$DESIGN_DIR/src" --top-module amd_am9511 "$DESIGN_DIR"/src/*.sv > "$WORK_DIR/lint.log" 2>&1
verilator --cc --exe --build -Wall -I"$DESIGN_DIR/src" --top-module amd_am9511 --Mdir "$WORK_DIR/obj" \
 -CFLAGS '-std=c++17 -O2' "$DESIGN_DIR"/src/*.sv "$DESIGN_DIR/tb/host_driver.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vamd_am9511" "$DESIGN_DIR/references/commands.csv" > "$WORK_DIR/run.log" 2>&1
cat "$WORK_DIR/run.log"
grep -q 'TEST PASSED:' "$WORK_DIR/run.log"
