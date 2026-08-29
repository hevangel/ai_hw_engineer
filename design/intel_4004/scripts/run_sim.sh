#!/bin/sh
# Run the deterministic self-checking simulation inside ai-hw-engineer:latest.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
LOG_FILE="$WORK_DIR/intel_4004.log"

mkdir -p "$WORK_DIR"

echo "=== xezim Intel 4004 regression ==="
xezim --simulate --sv2017 --error-exit \
    -s tb_intel_4004 \
    "$DESIGN_DIR/src/intel_4004.sv" \
    "$DESIGN_DIR/tb/tb_intel_4004.sv" \
    --max-time 80000000ns \
    -l "$LOG_FILE"

grep -q "4004 simulation result:" "$LOG_FILE"
grep -q "Phase A boundaries:" "$LOG_FILE"
if grep -q "TEST FAILED" "$LOG_FILE"; then
    echo "=== Simulation FAILED ==="
    exit 1
fi
grep -q "instruction id .* never executed" "$LOG_FILE" && {
    echo "=== Simulation FAILED (instruction coverage incomplete) ==="
    exit 1
}
grep -q "TEST PASSED" "$LOG_FILE"

echo "=== Simulation passed ==="
echo "Log: $LOG_FILE"
