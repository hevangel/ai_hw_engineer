#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
BUILD_DIR="$WORK_DIR/82288_sim"
mkdir -p "$BUILD_DIR"
if ! verilator --cc --exe --build -j 2 -Wall \
    --top-module intel_80286_82288 --Mdir "$BUILD_DIR" \
    "$DESIGN_DIR/src/intel_80286_82288.sv" \
    "$DESIGN_DIR/tb/82288.cpp" > "$BUILD_DIR/build.log" 2>&1; then
    cat "$BUILD_DIR/build.log" >&2
    exit 1
fi
cat "$BUILD_DIR/build.log"
if ! "$BUILD_DIR/Vintel_80286_82288" > "$BUILD_DIR/run.log" 2>&1; then
    cat "$BUILD_DIR/run.log" >&2
    exit 1
fi
cat "$BUILD_DIR/run.log"
