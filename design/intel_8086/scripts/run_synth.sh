#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/synth"
for top in intel_8086 intel_8086_chip; do
    # Generic-cell structural synthesis; avoid expensive default fraiging of
    # the combinational divider. This is not a target-library timing claim.
    yosys -Q -l "$DESIGN_DIR/work/synth/$top.log" -p "read_verilog -sv $DESIGN_DIR/src/*.sv; hierarchy -check -top $top; synth -noabc -top $top; abc -script +strash,map; check -assert; stat; write_json $DESIGN_DIR/work/synth/$top.json"
done
