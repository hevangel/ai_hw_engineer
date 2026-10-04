#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
mkdir -p "$WORK_DIR"
echo "=== Am9300 Yosys synthesis ==="
yosys -Q -l "$WORK_DIR/synth.log" -p "read_verilog -sv $DESIGN_DIR/src/amd_am9300.sv; hierarchy -check -top amd_am9300; synth -top amd_am9300; check -assert; write_json $WORK_DIR/amd_am9300.json"
grep -q 'End of script' "$WORK_DIR/synth.log"
