#!/bin/sh
# Run the deterministic self-checking simulation inside ai-hw-engineer:latest.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
LOG_FILE="$WORK_DIR/intel_8279.log"

mkdir -p "$WORK_DIR"

echo "=== xezim Intel 8279 regression ==="
xezim --simulate --sv2017 --error-exit \
    -s tb_intel_8279 \
    "$DESIGN_DIR/src/intel_8279.sv" \
    "$DESIGN_DIR/tb/tb_intel_8279.sv" \
    --max-time 200000ns \
    -l "$LOG_FILE"

grep -q "8279 simulation result:" "$LOG_FILE"
grep -q "Failures: 0" "$LOG_FILE"
grep -q "TEST PASSED" "$LOG_FILE"

xezim --simulate --sv2017 --error-exit \
    -s tb_intel_8279_timing \
    "$DESIGN_DIR/src/intel_8279.sv" \
    "$DESIGN_DIR/tb/tb_intel_8279_timing.sv" \
    --max-time 30000ns \
    -l "$WORK_DIR/intel_8279_timing.log"
grep -q "8279 default timing passed" "$WORK_DIR/intel_8279_timing.log"

echo "=== Simulation passed ==="
echo "Log: $LOG_FILE"
