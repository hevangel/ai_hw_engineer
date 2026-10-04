#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/synth"
yosys -p "read_verilog -sv $DESIGN_DIR/src/amd_am2901_alu.sv $DESIGN_DIR/src/amd_am2901.sv; hierarchy -check -top amd_am2901; synth -top amd_am2901; check -assert; stat" \
    > "$DESIGN_DIR/work/synth/synth.log" 2>&1
tail -55 "$DESIGN_DIR/work/synth/synth.log"
