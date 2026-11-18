#!/bin/sh
# Native-engine timing checks (bus-cycle-exact instructions).
#
# Usage: sh design/zilog_z80/scripts/run_native.sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/native"
OBJ_DIR="$WORK_DIR/obj_dir"

mkdir -p "$WORK_DIR"

VERILATOR=${VERILATOR:-verilator}

"$VERILATOR" \
    --cc --exe --build -j 0 -O2 \
    --top-module zilog_z80_native \
    --Mdir "$OBJ_DIR" \
    -I"$DESIGN_DIR/src" \
    "$DESIGN_DIR/src/zilog_z80_alu.sv" \
    "$DESIGN_DIR/src/zilog_z80.sv" \
    "$DESIGN_DIR/src/zilog_z80_native.sv" \
    "$DESIGN_DIR/tb/native_harness.cpp" \
    -o native_harness

"$OBJ_DIR/native_harness" "$@"
