#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
mkdir -p "$WORK_DIR"
echo "=== Am9300 exhaustive pin regression ==="
xezim --simulate --sv2017 --error-exit -s tb_top \
    "$DESIGN_DIR/src/amd_am9300.sv" "$DESIGN_DIR/tb/tb_top.sv" \
    --max-time 110000ns --fst "$WORK_DIR/amd_am9300.fst" \
    -l "$WORK_DIR/sim.log"
grep -q 'TEST PASSED:' "$WORK_DIR/sim.log"
grep -q '0 failures' "$WORK_DIR/sim.log"
cat "$WORK_DIR/sim.log"
