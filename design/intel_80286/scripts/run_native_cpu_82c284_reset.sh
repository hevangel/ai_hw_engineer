#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
BUILD_DIR="$WORK_DIR/native_cpu_82c284_reset_sim"
mkdir -p "$BUILD_DIR"
if ! verilator --cc --exe --build -j 2 -Wall \
    --top-module intel_80286_native_cpu -GRES_SYNC_DELAY_CLKS=2 \
    --Mdir "$BUILD_DIR" -CFLAGS "-std=c++17 -DTEST_82C284_RESET" \
    "$DESIGN_DIR"/src/*.sv "$DESIGN_DIR/tb/native_cpu.cpp" \
    > "$BUILD_DIR/build.log" 2>&1; then
    cat "$BUILD_DIR/build.log" >&2
    exit 1
fi
cat "$BUILD_DIR/build.log"
if ! "$BUILD_DIR/Vintel_80286_native_cpu" \
    > "$BUILD_DIR/run.log" 2>&1; then
    cat "$BUILD_DIR/run.log" >&2
    exit 1
fi
cat "$BUILD_DIR/run.log"
