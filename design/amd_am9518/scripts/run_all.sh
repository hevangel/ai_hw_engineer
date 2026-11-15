#!/bin/sh
# Run complete verification flow for the Am9518 design:
# lint -> formal (bmc/prove/cover) -> simulation suites -> synthesis.
#
# Usage: sh design/amd_am9518/scripts/run_all.sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")

echo "============================================"
echo "  Complete verification flow: amd_am9518"
echo "============================================"

echo ""
echo ">>> Step 1: Lint"
"$SCRIPT_DIR/run_lint.sh"

echo ""
echo ">>> Step 2: Formal (bmc/prove/cover)"
"$SCRIPT_DIR/run_formal.sh"

echo ""
echo ">>> Step 3: Simulation suites"
"$SCRIPT_DIR/run_sim.sh"

echo ""
echo ">>> Step 4: Synthesis"
"$SCRIPT_DIR/run_synth.sh"

echo ""
echo "============================================"
echo "  All steps completed for: amd_am9518"
echo "============================================"
