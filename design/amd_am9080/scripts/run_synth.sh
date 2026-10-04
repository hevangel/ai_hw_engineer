#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
mkdir -p "$WORK_DIR"
yosys -Q -l "$WORK_DIR/synth.log" -p "read_verilog -sv $DESIGN_DIR/src/amd_am9080_alu.sv $DESIGN_DIR/src/amd_am9080.sv; hierarchy -check -top amd_am9080; synth -top amd_am9080; check -assert; write_json $WORK_DIR/amd_am9080.json"
