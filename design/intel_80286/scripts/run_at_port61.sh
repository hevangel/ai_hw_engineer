#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
OUT_DIR="$WORK_DIR/at_port61"
mkdir -p "$OUT_DIR"
if ! verilator --binary --timing --assert -Wall --top-module intel_80286_at_port61_tb \
    --Mdir "$OUT_DIR/obj" -j 2 "$DESIGN_DIR/tb/intel_80286_at_port61.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_port61_tb.sv" > "$OUT_DIR/build.log" 2>&1; then
    cat "$OUT_DIR/build.log" >&2
    exit 1
fi
if ! "$OUT_DIR/obj/Vintel_80286_at_port61_tb" > "$OUT_DIR/sim.log" 2>&1; then
    cat "$OUT_DIR/sim.log" >&2
    exit 1
fi
cat "$OUT_DIR/sim.log"
