#!/bin/sh
# Re-run simulation and print durable functional-coverage evidence.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
LOG_FILE="$DESIGN_DIR/work/sim/intel_4004.log"

sh "$SCRIPT_DIR/run_sim.sh"

echo "=== Functional coverage evidence ==="
grep "4004 simulation result:" "$LOG_FILE"
grep "Phase A boundaries:" "$LOG_FILE"
grep "TEST PASSED" "$LOG_FILE"
