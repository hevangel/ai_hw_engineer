#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/synth"
yosys -p "read_verilog -sv $DESIGN_DIR/src/amd_am2918.sv; hierarchy -check -top amd_am2918; synth -top amd_am2918; check -assert; stat" \
    > "$DESIGN_DIR/work/synth/synth.log" 2>&1
tail -35 "$DESIGN_DIR/work/synth/synth.log"
