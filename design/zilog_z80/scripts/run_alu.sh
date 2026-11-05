#!/bin/sh
# Differential test: zilog_z80_alu against the pinned superzazu/z80 oracle.
#
# Builds a Verilator model of the ALU, links the unmodified emulator, and
# compares result and full flag byte for every ALU operation over an edge grid
# plus reproducible random operand pairs.
#
# Usage: sh design/zilog_z80/scripts/run_alu.sh [--negative-control]
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
REF_DIR="$DESIGN_DIR/references/superzazu_z80"
WORK_DIR="$DESIGN_DIR/work/alu"
OBJ_DIR="$WORK_DIR/obj_dir"

if [ ! -f "$REF_DIR/z80.c" ]; then
    echo "ERROR: pinned oracle missing at $REF_DIR/z80.c" >&2
    exit 1
fi

mkdir -p "$WORK_DIR"

VERILATOR=${VERILATOR:-verilator}

"$VERILATOR" \
    --cc --exe --build -j 0 -O2 \
    --top-module zilog_z80_alu \
    --Mdir "$OBJ_DIR" \
    -CFLAGS "-O2 -I$REF_DIR" \
    "$DESIGN_DIR/src/zilog_z80_pkg.sv" \
    "$DESIGN_DIR/src/zilog_z80_alu.sv" \
    "$DESIGN_DIR/tb/alu_harness.cpp" \
    "$REF_DIR/z80.c" \
    -o alu_harness

"$OBJ_DIR/alu_harness" "$@"
