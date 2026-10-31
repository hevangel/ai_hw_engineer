#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
mkdir -p "$WORK_DIR/cached_reference"
verilator --cc --exe --build -j 2 -Wall --top-module intel_80286_cached_reference \
    --Mdir "$WORK_DIR/cached_reference" \
    "$DESIGN_DIR/src/intel_80286_access_check.sv" \
    "$DESIGN_DIR/src/intel_80286_cached_reference.sv" \
    "$DESIGN_DIR/tb/cached_reference.cpp" > "$WORK_DIR/cached_reference/build.log" 2>&1
"$WORK_DIR/cached_reference/Vintel_80286_cached_reference"
