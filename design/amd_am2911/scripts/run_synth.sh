#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/synth"
yosys -p "read_verilog -sv $DESIGN_DIR/../amd_am2909/src/amd_am2909.sv $DESIGN_DIR/src/amd_am2911.sv; hierarchy -check -top amd_am2911; synth -top amd_am2911; check -assert; stat" \
    > "$DESIGN_DIR/work/synth/synth.log" 2>&1
tail -35 "$DESIGN_DIR/work/synth/synth.log"
