#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$DESIGN_DIR/../.." && pwd)
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
OUT_DIR="$WORK_DIR/at_timer_fixture"
mkdir -p "$OUT_DIR"

if ! verilator --binary --timing -Wall --top-module intel_80286_at_timer_tb \
    --Mdir "$OUT_DIR/obj" -j 2 \
    "$REPO_DIR/design/intel_8253_8254/src/intel_8253_8254.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_timer.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_timer_tb.sv" > "$OUT_DIR/build.log" 2>&1; then
    cat "$OUT_DIR/build.log"
    exit 1
fi
if ! "$OUT_DIR/obj/Vintel_80286_at_timer_tb" > "$OUT_DIR/sim.log" 2>&1; then
    cat "$OUT_DIR/sim.log"
    exit 1
fi
cat "$OUT_DIR/sim.log"
