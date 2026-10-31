#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}

for delay in 1 2; do
    BUILD_DIR="$WORK_DIR/82c284_reset_${delay}clk"
    mkdir -p "$BUILD_DIR"
    if ! verilator --cc --exe --build -j 2 -Wall \
        --top-module intel_80286_82c284_reset \
        -GRES_SYNC_DELAY_CLKS="$delay" --Mdir "$BUILD_DIR" \
        -CFLAGS "-std=c++17" \
        "$DESIGN_DIR/src/intel_80286_82c284_reset.sv" \
        "$DESIGN_DIR/tb/82c284_reset.cpp" \
        > "$BUILD_DIR/build.log" 2>&1; then
        cat "$BUILD_DIR/build.log" >&2
        exit 1
    fi
    cat "$BUILD_DIR/build.log"
    if ! "$BUILD_DIR/Vintel_80286_82c284_reset" "$delay" \
        > "$BUILD_DIR/run.log" 2>&1; then
        cat "$BUILD_DIR/run.log" >&2
        exit 1
    fi
    cat "$BUILD_DIR/run.log"
done
