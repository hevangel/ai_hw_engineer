#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/synth"
yosys -Q -l "$DESIGN_DIR/work/synth/synth.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_8086_alu.sv $DESIGN_DIR/src/intel_8086.sv; hierarchy -check -top intel_8086; synth -top intel_8086; check -assert; write_json $DESIGN_DIR/work/synth/intel_8086.json"
