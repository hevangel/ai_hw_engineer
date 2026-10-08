#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
mkdir -p "$WORK_DIR"
yosys -Q -l "$WORK_DIR/synth.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_8080_alu.sv $DESIGN_DIR/src/intel_8080.sv; hierarchy -check -top intel_8080; synth -top intel_8080; check -assert; write_json $WORK_DIR/intel_8080.json"
