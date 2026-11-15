#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
mkdir -p "$WORK_DIR"
echo "=== Am26LS32 Yosys synthesis ==="
yosys -Q -l "$WORK_DIR/synth.log" -p "read_verilog -sv $DESIGN_DIR/src/am26ls32.sv; hierarchy -check -top am26ls32; synth -top am26ls32; check -assert; stat; write_json $WORK_DIR/am26ls32.json"
grep -q 'End of script' "$WORK_DIR/synth.log"
echo "Am26LS32 SYNTHESIS PASSED; log: $WORK_DIR/synth.log"
