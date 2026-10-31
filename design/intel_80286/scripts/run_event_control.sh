#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
mkdir -p "$WORK_DIR/event_control"
echo '=== Intel 80286 standalone event-controller contracts ==='
verilator --cc --exe --build -j 2 -Wall --top-module intel_80286_event_control \
    --Mdir "$WORK_DIR/event_control" \
    "$DESIGN_DIR/src/intel_80286_event_control.sv" "$DESIGN_DIR/tb/event_control.cpp"
"$WORK_DIR/event_control/Vintel_80286_event_control"
