#!/bin/sh
# Run the deterministic self-checking simulation inside ai-hw-engineer:latest.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
LOG_FILE="$WORK_DIR/intel_8259.log"

mkdir -p "$WORK_DIR"

echo "=== xezim Intel 8259 regression ==="
xezim --simulate --sv2017 --error-exit \
    -s tb_intel_8259 \
    "$DESIGN_DIR/src/intel_8259.sv" \
    "$DESIGN_DIR/tb/tb_intel_8259.sv" \
    --max-time 200000ns \
    -l "$LOG_FILE"

grep -q "Pseudorandom seed: 0x8259, operations: 2048" "$LOG_FILE"
grep -q "8259 simulation result:" "$LOG_FILE"
grep -q "Failures: 0" "$LOG_FILE"
grep -q "TEST PASSED" "$LOG_FILE"

echo "=== Simulation passed ==="
echo "Log: $LOG_FILE"
