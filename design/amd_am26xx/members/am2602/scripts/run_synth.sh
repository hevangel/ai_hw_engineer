#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
mkdir -p "$WORK_DIR"
echo "=== Am2602 Yosys synthesis ==="
yosys -Q -l "$WORK_DIR/synth.log" -p "read_verilog -sv $DESIGN_DIR/src/am2602.sv; hierarchy -check -top am2602; synth -top am2602; check -assert; stat; write_json $WORK_DIR/am2602.json"
grep -q 'End of script' "$WORK_DIR/synth.log"
echo "Am2602 SYNTHESIS PASSED; log: $WORK_DIR/synth.log"
