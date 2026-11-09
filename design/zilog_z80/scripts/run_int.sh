#!/bin/sh
# Directed interrupt tests for the Z80 core.
#
# Usage: sh design/zilog_z80/scripts/run_int.sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/int"
OBJ_DIR="$WORK_DIR/obj_dir"

mkdir -p "$WORK_DIR"

VERILATOR=${VERILATOR:-verilator}

"$VERILATOR" \
    --cc --exe --build -j 0 -O2 \
    --top-module zilog_z80 \
    --Mdir "$OBJ_DIR" \
    -I"$DESIGN_DIR/src" \
    "$DESIGN_DIR/src/zilog_z80_alu.sv" \
    "$DESIGN_DIR/src/zilog_z80.sv" \
    "$DESIGN_DIR/tb/int_harness.cpp" \
    -o int_harness

"$OBJ_DIR/int_harness" "$@"
