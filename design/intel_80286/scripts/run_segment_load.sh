#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
mkdir -p "$WORK_DIR/segment_load"
echo '=== Intel 80286 protected segment-load transactions ==='
verilator --cc --exe --build -j 2 -Wall --top-module intel_80286_segment_load \
    --Mdir "$WORK_DIR/segment_load" \
    "$DESIGN_DIR/src/intel_80286_segment_check.sv" "$DESIGN_DIR/src/intel_80286_segment_load.sv" \
    "$DESIGN_DIR/tb/segment_load.cpp"
"$WORK_DIR/segment_load/Vintel_80286_segment_load"
