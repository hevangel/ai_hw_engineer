#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
mkdir -p "$WORK_DIR"
echo "=== Am26LS31 Yosys synthesis ==="
yosys -Q -l "$WORK_DIR/synth.log" -p "read_verilog -sv $DESIGN_DIR/src/am26ls31.sv; hierarchy -check -top am26ls31; synth -top am26ls31; check -assert; stat; write_json $WORK_DIR/am26ls31.json"
grep -q 'End of script' "$WORK_DIR/synth.log"
echo "Am26LS31 SYNTHESIS PASSED; log: $WORK_DIR/synth.log"
