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
read_verilog -sv $DESIGN_DIR/src/intel_8251.sv
hierarchy -check -top intel_8251
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
write_verilog -noattr $WORK_DIR/intel_8251_synth.v
write_json $WORK_DIR/intel_8251_synth.json
EOF

echo "=== Yosys generic synthesis ==="
yosys -Q -s "$SYNTH_SCRIPT" -l "$LOG_FILE"

# Yosys 0.46 reports "Number of cells:" while 0.59 reports a local-count tree,
# so accept either statistics format.
grep -q "Found and reported 0 problems" "$LOG_FILE"
grep -qE "Number of cells:|[0-9]+ cells" "$LOG_FILE"

echo "=== Synthesis passed ==="
echo "Log: $LOG_FILE"
