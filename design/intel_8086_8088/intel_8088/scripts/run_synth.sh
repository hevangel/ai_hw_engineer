#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/synth"
EU_SRC="$DESIGN_DIR/../intel_8086/src"
for top in intel_8088_biu intel_8088_chip; do
    # Generic-cell structural synthesis; the shared 8086 execution-unit
    # synthesis lives in its own member. This is not a timing claim.
    yosys -Q -l "$DESIGN_DIR/work/synth/$top.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_8088_biu.sv $DESIGN_DIR/src/intel_8088_chip.sv $EU_SRC/intel_8086.sv $EU_SRC/intel_8086_alu.sv $EU_SRC/intel_8086_muldiv.sv $EU_SRC/intel_8086_shift.sv; hierarchy -check -top $top; synth -noabc -top $top; abc -script +strash,map; check -assert; stat; write_json $DESIGN_DIR/work/synth/$top.json"
done
