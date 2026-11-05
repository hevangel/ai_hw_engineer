#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
MEMBER_SRC="$DESIGN_DIR/src"
EU_SRC="$DESIGN_DIR/../intel_8086/src"
mkdir -p "$DESIGN_DIR/work/verilator"
verilator --cc --exe --build -j 4 --assert --public-flat-rw -Wall \
    --top-module intel_8088_chip --Mdir "$DESIGN_DIR/work/verilator" \
    "$MEMBER_SRC/intel_8088_biu.sv" "$MEMBER_SRC/intel_8088_chip.sv" \
    "$EU_SRC/intel_8086.sv" "$EU_SRC/intel_8086_alu.sv" \
    "$EU_SRC/intel_8086_muldiv.sv" "$EU_SRC/intel_8086_shift.sv" \
    "$DESIGN_DIR/tb/tb_native.cpp" > "$DESIGN_DIR/work/verilator/build.log" 2>&1
