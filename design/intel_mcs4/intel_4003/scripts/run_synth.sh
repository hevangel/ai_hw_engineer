#!/bin/sh
# Run generic Yosys synthesis inside ai-hw-engineer:latest.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
LOG_FILE="$WORK_DIR/intel_4003_synth.log"

mkdir -p "$WORK_DIR"

echo "=== Yosys generic synthesis: intel_4003 ==="
yosys -p "read_verilog -sv $DESIGN_DIR/src/intel_4003.sv; \
          hierarchy -top intel_4003 -check; \
          proc; opt; fsm; opt; memory; opt; \
          techmap; opt_clean; stat" \
       -l "$LOG_FILE"

grep -q "End of script" "$LOG_FILE"
grep -q "Printing statistics" "$LOG_FILE"

echo "=== Synthesis passed ==="
echo "Log: $LOG_FILE"
