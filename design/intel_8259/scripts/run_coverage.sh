#!/bin/sh
# Re-run simulation and print durable functional-coverage evidence.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
LOG_FILE="$DESIGN_DIR/work/sim/intel_8259.log"

sh "$SCRIPT_DIR/run_sim.sh"

echo "=== Functional coverage evidence ==="
grep "8259 simulation result:" "$LOG_FILE"
grep "CPU reads:" "$LOG_FILE"
grep "INTA sequences:" "$LOG_FILE"
grep "IR rising edges:" "$LOG_FILE"
grep "Failures:" "$LOG_FILE"
