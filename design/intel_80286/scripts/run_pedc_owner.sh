#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
BUILD_DIR="$WORK_DIR/pedc_owner_sim"
mkdir -p "$BUILD_DIR"
if ! verilator --binary --timing --timescale 1ns/1ps -Wall \
    --top-module intel_80286_pedc_owner_tb --Mdir "$BUILD_DIR" \
    "$DESIGN_DIR/src/intel_80286_bus_owner.sv" "$DESIGN_DIR/src/intel_80286_pedc.sv" \
    "$DESIGN_DIR/tb/intel_80286_pedc_owner_tb.sv" > "$BUILD_DIR/build.log" 2>&1; then
    cat "$BUILD_DIR/build.log" >&2
    exit 1
fi
"$BUILD_DIR/Vintel_80286_pedc_owner_tb"
