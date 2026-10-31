#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
ROOT_DIR=$(dirname "$(dirname "$DESIGN_DIR")")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
OUT_DIR="$WORK_DIR/at_refresh_timer_native"
mkdir -p "$OUT_DIR"
# The native CPU uses synchronous reset while the board TTL uses asynchronous
# reset; both intentionally share the fixture's reset net.
if ! verilator --binary --timing --assert -j 2 -Wall -Wno-SYNCASYNCNET \
    --top-module intel_80286_at_refresh_timer_native_tb --Mdir "$OUT_DIR/obj" \
    "$DESIGN_DIR"/src/*.sv "$ROOT_DIR/design/intel_8253_8254/src/intel_8253_8254.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_timer.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_port61.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_request.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_arbiter.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_detect.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_row.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_path.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_native.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_timer_native.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_timer_native_tb.sv" > "$OUT_DIR/build.log" 2>&1; then
    cat "$OUT_DIR/build.log" >&2
    exit 1
fi
if ! "$OUT_DIR/obj/Vintel_80286_at_refresh_timer_native_tb" > "$OUT_DIR/sim.log" 2>&1; then
    cat "$OUT_DIR/sim.log" >&2
    exit 1
fi
cat "$OUT_DIR/sim.log"
