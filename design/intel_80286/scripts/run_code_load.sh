#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
mkdir -p "$WORK_DIR/code_load"
verilator --cc --exe --build -j 2 -Wall --top-module intel_80286_code_load \
    --Mdir "$WORK_DIR/code_load" "$DESIGN_DIR/src/intel_80286_code_check.sv" \
    "$DESIGN_DIR/src/intel_80286_code_load.sv" "$DESIGN_DIR/tb/code_load.cpp" \
    > "$WORK_DIR/code_load/build.log" 2>&1
"$WORK_DIR/code_load/Vintel_80286_code_load"
