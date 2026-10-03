#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
mkdir -p "$WORK_DIR"
echo "=== Am2505 Yosys synthesis ==="
yosys -Q -l "$WORK_DIR/synth.log" -p "read_verilog -sv $DESIGN_DIR/src/amd_am2505.sv; hierarchy -check -top amd_am2505; synth -top amd_am2505; check -assert; write_json $WORK_DIR/amd_am2505.json"
grep -q 'End of script' "$WORK_DIR/synth.log"
