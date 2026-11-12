#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/synth"
yosys -Q -p "read_verilog -sv -I$DESIGN_DIR/src $DESIGN_DIR/src/amd_am9513.sv; hierarchy -check -top amd_am9513; synth -top amd_am9513 -noabc; abc -lut 4 -script +strash,if,-K,4; check -assert; stat" > "$DESIGN_DIR/work/synth/yosys.log" 2>&1
tail -40 "$DESIGN_DIR/work/synth/yosys.log"
echo "TEST PASSED: Am9513 synthesis/check (generic four-input LUT mapping)"