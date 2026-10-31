#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
BUILD_DIR="$WORK_DIR/bus_owner_sim"
mkdir -p "$BUILD_DIR"
verilator --cc --exe --build -j 2 -Wall \
    --top-module intel_80286_bus_owner --Mdir "$BUILD_DIR" \
    "$DESIGN_DIR/src/intel_80286_bus_owner.sv" \
    "$DESIGN_DIR/tb/bus_owner.cpp"
"$BUILD_DIR/Vintel_80286_bus_owner"
