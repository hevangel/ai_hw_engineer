#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
mkdir -p "$WORK_DIR"
echo "=== Am2501 Yosys synthesis ==="
for enables in 6 2; do
    yosys -Q -l "$WORK_DIR/synth_$enables.log" -p "read_verilog -sv $DESIGN_DIR/src/amd_am2501.sv; chparam -set CE_INPUTS $enables amd_am2501; hierarchy -check -top amd_am2501; synth -top amd_am2501; check -assert; write_json $WORK_DIR/amd_am2501_$enables.json"
    grep -q 'End of script' "$WORK_DIR/synth_$enables.log"
done
