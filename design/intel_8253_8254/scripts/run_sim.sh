#!/bin/sh
# Run the deterministic dual-variant self-checking regression.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
LOG_FILE="$WORK_DIR/intel_8253_8254.log"

mkdir -p "$WORK_DIR"

echo "=== xezim Intel 8253/8254 regression ==="
xezim --simulate --sv2017 --error-exit \
    -s tb_top \
    "$DESIGN_DIR/src/intel_8253_8254.sv" \
    "$DESIGN_DIR/tb/tb_top.sv" \
    --max-time 300000ns \
    -l "$LOG_FILE"

grep -q "Pseudorandom seed: 0x8254, operations: 64" "$LOG_FILE"
grep -q "Mode/channel scenarios: 18, aliases: 2, GATE: 5" "$LOG_FILE"
grep -q "Latch checks: 10, read-back checks: 9, BCD checks: 15, phase checks: 2" "$LOG_FILE"
grep -q "Stress operations: 64" "$LOG_FILE"
grep -q "Failures: 0" "$LOG_FILE"
grep -q "TEST PASSED" "$LOG_FILE"

echo "=== Simulation passed ==="
echo "Log: $LOG_FILE"
