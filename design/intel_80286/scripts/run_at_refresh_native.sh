#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
OUT_DIR="$WORK_DIR/at_refresh_native"
mkdir -p "$OUT_DIR"
# The CPU samples RESET synchronously while the board TTL uses asynchronous
# clears; this intentionally shares the system reset with both kinds of flop.
if ! verilator --cc --exe --build -j 2 -Wall -Wno-SYNCASYNCNET --top-module intel_80286_at_refresh_native \
    --Mdir "$OUT_DIR/obj" -CFLAGS '-std=c++17' "$DESIGN_DIR"/src/*.sv \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_request.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_arbiter.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_detect.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_row.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_path.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_native.sv" \
    "$DESIGN_DIR/tb/at_refresh_native.cpp" > "$OUT_DIR/build.log" 2>&1; then
    cat "$OUT_DIR/build.log" >&2
    exit 1
fi
if ! "$OUT_DIR/obj/Vintel_80286_at_refresh_native" > "$OUT_DIR/sim.log" 2>&1; then
    cat "$OUT_DIR/sim.log" >&2
    exit 1
fi
cat "$OUT_DIR/sim.log"
