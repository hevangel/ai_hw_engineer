#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
mkdir -p "$WORK_DIR/segment_check"
echo '=== Intel 80286 protected segment-check component ==='
verilator --cc --exe --build -j 2 -Wall --top-module intel_80286_segment_check \
    --Mdir "$WORK_DIR/segment_check" \
    "$DESIGN_DIR/src/intel_80286_segment_check.sv" "$DESIGN_DIR/tb/segment_check.cpp"
"$WORK_DIR/segment_check/Vintel_80286_segment_check"
