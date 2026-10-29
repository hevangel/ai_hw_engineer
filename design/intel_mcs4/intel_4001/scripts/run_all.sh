#!/bin/bash
# Run the complete verification flow for intel_4001:
#   1. Verilator lint (-Wall, zero warnings expected)
#   2. SymbiYosys formal (bmc, prove, cover)
#   3. xezim simulation (direct self-checking testbench)
#   4. Yosys synthesis check
# Usage: ./run_all.sh

set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work"

echo "============================================"
echo "  Complete verification flow: intel_4001"
echo "============================================"
echo ""

STATUS=0

echo ">>> Step 1: Verilator lint"
mkdir -p "$WORK_DIR/lint"
if verilator --lint-only -Wall --top-module intel_4001 \
        "$DESIGN_DIR/src/intel_4001.sv" \
        2> "$WORK_DIR/lint/lint_rtl.log"; then
    echo "  PASS: RTL lint clean"
else
    echo "  FAIL: RTL lint"
    cat "$WORK_DIR/lint/lint_rtl.log"
    STATUS=1
fi
echo ""

echo ">>> Step 2: Formal verification"
if ! "$SCRIPT_DIR/run_formal.sh" all; then
    STATUS=1
fi
echo ""

echo ">>> Step 3: Simulation"
if ! "$SCRIPT_DIR/run_sim.sh"; then
    STATUS=1
fi
echo ""

echo ">>> Step 4: Yosys synthesis"
if ! "$SCRIPT_DIR/run_synth.sh" generic; then
    STATUS=1
fi
echo ""

if [ $STATUS -eq 0 ]; then
    echo "=== All steps PASSED for intel_4001 ==="
else
    echo "=== One or more steps FAILED for intel_4001 ==="
fi
exit $STATUS
