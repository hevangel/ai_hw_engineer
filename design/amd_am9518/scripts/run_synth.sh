#!/bin/sh
# Run synthesis with Yosys (generic).
#
# Usage: sh design/amd_am9518/scripts/run_synth.sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"

mkdir -p "$WORK_DIR"

SYNTH_SCRIPT="$WORK_DIR/synth.ys"
cat > "$SYNTH_SCRIPT" <<EOF
# Auto-generated synthesis script for amd_am9518
read_verilog -sv -I$DESIGN_DIR/src $DESIGN_DIR/src/des_core.sv
read_verilog -sv -I$DESIGN_DIR/src $DESIGN_DIR/src/amd_am9518_top.sv
hierarchy -top amd_am9518_top -check
proc
flatten
opt -full
fsm
opt
memory
opt
techmap
opt_clean
stat
write_verilog -noattr $WORK_DIR/amd_am9518_synth.v
write_json $WORK_DIR/amd_am9518_synth.json
EOF

yosys -s "$SYNTH_SCRIPT" -l "$WORK_DIR/synth.log"

echo "=== synthesis complete: $WORK_DIR/synth.log ==="
