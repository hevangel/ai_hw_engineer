#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
mkdir -p "$WORK_DIR"
echo "=== Am26S12A Yosys synthesis ==="
yosys -Q -l "$WORK_DIR/synth.log" -p "read_verilog -sv $DESIGN_DIR/../am26s12/src/am26s12.sv; chparam -set REVISION 1 am26s12; hierarchy -check -top am26s12; synth -top am26s12; check -assert; stat; write_json $WORK_DIR/am26s12a.json"
grep -q 'End of script' "$WORK_DIR/synth.log"
echo "Am26S12A SYNTHESIS PASSED; log: $WORK_DIR/synth.log"
