#!/bin/sh
# Run the complete verification flow inside ai-hw-engineer:latest.
# Usage: run_all.sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work"

echo "============================================"
echo "  Complete verification flow: intel_4003"
echo "============================================"
echo ""

# 1. Lint (RTL, then testbench separately)
echo ">>> Step 1: Verilator lint"
mkdir -p "$WORK_DIR/lint"
verilator --lint-only -Wall --top-module intel_4003 \
    "$DESIGN_DIR/src/intel_4003.sv" 2>&1 | tee "$WORK_DIR/lint/rtl_lint.log"
verilator --lint-only -Wall --top-module tb_intel_4003 \
    "$DESIGN_DIR/src/intel_4003.sv" "$DESIGN_DIR/tb/tb_intel_4003.sv" \
    2>&1 | tee "$WORK_DIR/lint/tb_lint.log"
echo "  Lint clean"
echo ""

# 2. Formal verification (bmc, prove, cover)
echo ">>> Step 2: Formal verification"
"$SCRIPT_DIR/run_formal.sh" all
echo ""

# 3. Simulation
echo ">>> Step 3: Simulation"
"$SCRIPT_DIR/run_sim.sh"
echo ""

# 4. Synthesis
echo ">>> Step 4: Synthesis"
"$SCRIPT_DIR/run_synth.sh"
echo ""

echo "============================================"
echo "  All steps completed for: intel_4003"
echo "============================================"
