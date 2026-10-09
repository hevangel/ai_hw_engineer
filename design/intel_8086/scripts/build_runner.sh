#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/verilator"
verilator --cc --exe --build -j 4 --assert --public-flat-rw -Wall \
    --top-module intel_8086 --Mdir "$DESIGN_DIR/work/verilator" \
    "$DESIGN_DIR/src/intel_8086_alu.sv" "$DESIGN_DIR/src/intel_8086.sv" \
    "$DESIGN_DIR/tb/tb_vectors.cpp" > "$DESIGN_DIR/work/verilator/build.log" 2>&1
