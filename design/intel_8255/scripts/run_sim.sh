#!/bin/sh
# Run the deterministic self-checking simulation inside ai-hw-engineer:latest.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
LOG_FILE="$WORK_DIR/intel_8255.log"

mkdir -p "$WORK_DIR"

echo "=== xezim Intel 8255 regression ==="
xezim --simulate --sv2017 --error-exit \
    -s tb_intel_8255 \
    "$DESIGN_DIR/src/intel_8255.sv" \
    "$DESIGN_DIR/tb/tb_intel_8255.sv" \
    --max-time 100000ns \
    -l "$LOG_FILE"

grep -q "Pseudorandom seed: 0x1ace, operations: 1024" "$LOG_FILE"
grep -q "Mode 0 directions: 16, BSR actions: 16, Mode 1 scenarios: 4, Mode 2 scenarios: 3" "$LOG_FILE"
grep -q "Failures: 0" "$LOG_FILE"
grep -q "TEST PASSED" "$LOG_FILE"

echo "=== Simulation passed ==="
echo "Log: $LOG_FILE"
