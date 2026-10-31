#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
mkdir -p "$WORK_DIR/access_check"
verilator --cc --exe --build -j 2 -Wall --top-module intel_80286_access_check \
    --Mdir "$WORK_DIR/access_check" "$DESIGN_DIR/src/intel_80286_access_check.sv" \
    "$DESIGN_DIR/tb/access_check.cpp" > "$WORK_DIR/access_check/build.log" 2>&1
"$WORK_DIR/access_check/Vintel_80286_access_check"
