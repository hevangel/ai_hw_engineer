#!/bin/bash
# Run complete verification flow
# Usage: ./run_all.sh

set -e

SCRIPT_DIR=$(dirname $(realpath $0))
DESIGN_DIR=$(dirname $SCRIPT_DIR)
CHIP_NAME=$(basename $DESIGN_DIR)

echo "============================================"
echo "  Complete verification flow: $CHIP_NAME"
echo "============================================"
echo ""

# 1. Formal verification
echo ">>> Step 1: Formal Verification"
if [ -d "$DESIGN_DIR/formal" ] && ls $DESIGN_DIR/formal/*.sby 1>/dev/null 2>&1; then
    $SCRIPT_DIR/run_formal.sh
else
    echo "  SKIP: No .sby files found"
fi
echo ""

# 2. Simulation
echo ">>> Step 2: Simulation"
if [ -f "$DESIGN_DIR/tb/tb_top.sv" ]; then
    $SCRIPT_DIR/run_sim.sh base_test
else
    echo "  SKIP: No tb_top.sv found"
fi
echo ""

# 3. Synthesis
echo ">>> Step 3: Synthesis"
$SCRIPT_DIR/run_synth.sh generic
echo ""

echo "============================================"
echo "  All steps completed for: $CHIP_NAME"
echo "============================================"
