#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
mkdir -p "$WORK_DIR"
echo "=== Am26L123 Yosys synthesis ==="
yosys -Q -l "$WORK_DIR/synth.log" -p "read_verilog -sv $DESIGN_DIR/src/am26l123.sv; hierarchy -check -top am26l123; synth -top am26l123; check -assert; stat; write_json $WORK_DIR/am26l123.json"
grep -q 'End of script' "$WORK_DIR/synth.log"
echo "Am26L123 SYNTHESIS PASSED; log: $WORK_DIR/synth.log"
