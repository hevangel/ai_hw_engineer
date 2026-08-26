#!/bin/sh
# Re-run simulation and print durable functional coverage evidence.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
LOG_FILE="$DESIGN_DIR/work/sim/intel_8253_8254.log"

sh "$SCRIPT_DIR/run_sim.sh"

echo "=== Functional coverage evidence ==="
grep "8253/8254 simulation result:" "$LOG_FILE"
grep "CPU reads:" "$LOG_FILE"
grep "Mode/channel scenarios:" "$LOG_FILE"
grep "Latch checks:" "$LOG_FILE"
grep "Stress operations:" "$LOG_FILE"
grep "Failures:" "$LOG_FILE"
