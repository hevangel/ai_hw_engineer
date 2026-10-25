#!/bin/sh
# Run deterministic generic Yosys synthesis inside ai-hw-engineer:latest.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
SYNTH_SCRIPT="$WORK_DIR/synth.ys"
LOG_FILE="$WORK_DIR/synth.log"

mkdir -p "$WORK_DIR"

cat > "$SYNTH_SCRIPT" <<EOF
read_verilog -sv $DESIGN_DIR/src/alu_74181.sv
hierarchy -check -top alu_74181
proc
flatten
opt -full
techmap
opt -full
check
stat
write_verilog -noattr $WORK_DIR/alu_74181_synth.v
write_json $WORK_DIR/alu_74181_synth.json
EOF

yosys -Q -s "$SYNTH_SCRIPT" -l "$LOG_FILE"
cat "$LOG_FILE"
grep -Fq "Found and reported 0 problems." "$LOG_FILE"
grep -Eq "Number of cells:|^[[:space:]]*[0-9]+ cells$" "$LOG_FILE"

echo "=== Synthesis passed ==="
echo "Netlist: $WORK_DIR/alu_74181_synth.v"
echo "JSON:    $WORK_DIR/alu_74181_synth.json"
