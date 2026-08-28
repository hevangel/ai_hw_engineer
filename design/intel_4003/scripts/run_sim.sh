#!/bin/sh
# Run the deterministic self-checking simulation inside ai-hw-engineer:latest.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
LOG_FILE="$WORK_DIR/intel_4003.log"

mkdir -p "$WORK_DIR"

echo "=== xezim Intel 4003 regression ==="
xezim --simulate --sv2017 --error-exit \
    -s tb_intel_4003 \
    "$DESIGN_DIR/src/intel_4003.sv" \
    "$DESIGN_DIR/tb/tb_intel_4003.sv" \
    --fst "$WORK_DIR/intel_4003.fst" \
    --max-time 2000000ns \
    -l "$LOG_FILE"

# The simulator may still exit 0 on a failed test: require the pass line
# and the zero-failure summary in the log.
grep -q "TEST PASSED" "$LOG_FILE"
grep -q "0 failures" "$LOG_FILE"

echo "=== Simulation passed ==="
echo "Log: $LOG_FILE"
