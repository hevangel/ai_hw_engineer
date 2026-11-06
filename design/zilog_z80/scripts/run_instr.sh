#!/bin/sh
# Instruction-level differential test: zilog_z80 core against the pinned oracle.
#
# Both models run the same byte program from reset (JP 0x0100, a prologue that
# sets random registers and flags, then the instruction under test). Encodings
# the core does not implement raise fault_o and are reported as unimplemented.
#
# Usage: sh design/zilog_z80/scripts/run_instr.sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
REF_DIR="$DESIGN_DIR/references/superzazu_z80"
WORK_DIR="$DESIGN_DIR/work/instr"
OBJ_DIR="$WORK_DIR/obj_dir"

if [ ! -f "$REF_DIR/z80.c" ]; then
    echo "ERROR: pinned oracle missing at $REF_DIR/z80.c" >&2
    exit 1
fi

mkdir -p "$WORK_DIR"

VERILATOR=${VERILATOR:-verilator}

"$VERILATOR" \
    --cc --exe --build -j 0 -O2 \
    --top-module zilog_z80 \
    --Mdir "$OBJ_DIR" \
    -I"$DESIGN_DIR/src" \
    -CFLAGS "-O2 -I$REF_DIR" \
    "$DESIGN_DIR/src/zilog_z80_alu.sv" \
    "$DESIGN_DIR/src/zilog_z80.sv" \
    "$DESIGN_DIR/tb/instr_harness.cpp" \
    "$REF_DIR/z80.c" \
    -o instr_harness

"$OBJ_DIR/instr_harness" "$@"
