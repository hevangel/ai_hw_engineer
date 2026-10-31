#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
BUILD_DIR="$WORK_DIR/native_core_sim"
mkdir -p "$BUILD_DIR"
if ! verilator --cc --exe --build -j 2 -Wall -GNATIVE_BEATS=1 \
    --top-module intel_80286 --Mdir "$BUILD_DIR" -CFLAGS "-std=c++17" \
    "$DESIGN_DIR"/src/*.sv "$DESIGN_DIR/tb/native_core.cpp" > "$BUILD_DIR/build.log" 2>&1; then
    cat "$BUILD_DIR/build.log" >&2
    exit 1
fi
cat "$BUILD_DIR/build.log"
if ! "$BUILD_DIR/Vintel_80286" > "$BUILD_DIR/run.log" 2>&1; then
    cat "$BUILD_DIR/run.log" >&2
    exit 1
fi
cat "$BUILD_DIR/run.log"
