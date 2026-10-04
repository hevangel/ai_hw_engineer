#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/synth"
python3 "$SCRIPT_DIR/generate_commands.py" --check
python3 "$SCRIPT_DIR/generate_derived_constants.py" --check
yosys -Q -p "read_verilog -sv -I$DESIGN_DIR/src $DESIGN_DIR/src/*.sv; hierarchy -check -top amd_am9511; synth -top amd_am9511 -noabc; abc -lut 4 -script +strash,if,-K,4; check -assert; stat" > "$DESIGN_DIR/work/synth/yosys.log" 2>&1
tail -40 "$DESIGN_DIR/work/synth/yosys.log"
echo "TEST PASSED: Am9511 synthesis/check (generic four-input LUT mapping)"
