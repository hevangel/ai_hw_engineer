#!/bin/sh
# Headless bring-up run of the BUSICOM 141-PF virtual platform.
# Runs the authentic calculator firmware on the reconstructed MCS-4 board
# (no host bridge) and self-checks that the keyboard scan sweeps all rows.
#
#   sh scripts/run_sim.sh [machine_cycles]
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYSTEM_DIR=$(dirname "$SCRIPT_DIR")
DESIGN_DIR="$SYSTEM_DIR/../../design"
WORK_DIR="$SYSTEM_DIR/work/sim"
LOG_FILE="$WORK_DIR/busicom_141pf.log"

CHECK_CYCLES="${1:-600000}"

mkdir -p "$WORK_DIR"
# $readmemh paths in the board resolve against the simulator's working
# directory (src/rom/rom_4001_N.hex), so run from the system folder.
cd "$SYSTEM_DIR"

echo "=== BUSICOM 141-PF headless bring-up ==="
xezim --simulate --sv2017 --error-exit \
    -s tb_top \
    +cycles=$CHECK_CYCLES \
    "$DESIGN_DIR/intel_4004/src/intel_4004.sv" \
    "$DESIGN_DIR/intel_4001/src/intel_4001.sv" \
    "$DESIGN_DIR/intel_4002/src/intel_4002.sv" \
    "$DESIGN_DIR/intel_4003/src/intel_4003.sv" \
    "$SYSTEM_DIR/src/busicom_141pf.sv" \
    "$SYSTEM_DIR/tb/tb_top.sv" \
    --max-time 200000000ns \
    -l "$LOG_FILE"

grep -q "SYSTEM SELF-TEST PASS" "$LOG_FILE"

echo "=== Bring-up passed ==="
echo "Log: $LOG_FILE"
