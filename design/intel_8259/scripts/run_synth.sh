#!/bin/sh
# Run deterministic generic synthesis inside ai-hw-engineer:latest.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
SYNTH_SCRIPT="$WORK_DIR/synth.ys"
LOG_FILE="$WORK_DIR/synth.log"

mkdir -p "$WORK_DIR"

cat > "$SYNTH_SCRIPT" <<EOF
read_verilog -sv $DESIGN_DIR/src/intel_8259.sv
hierarchy -check -top intel_8259
proc
flatten
opt -full
fsm
memory
opt -full
techmap
opt -full
check
stat
write_verilog -noattr $WORK_DIR/intel_8259_synth.v
write_json $WORK_DIR/intel_8259_synth.json
EOF

echo "=== Yosys generic synthesis ==="
yosys -Q -s "$SYNTH_SCRIPT" -l "$LOG_FILE"

grep -q "Found and reported 0 problems" "$LOG_FILE"
grep -q "Number of cells:" "$LOG_FILE"

echo "=== Synthesis passed ==="
echo "Log: $LOG_FILE"
