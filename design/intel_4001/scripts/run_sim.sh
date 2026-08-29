#!/bin/bash
# Run the intel_4001 direct (non-UVM) testbench on xezim.
# Usage: ./run_sim.sh [work_dir]
#
# xezim may exit 0 even when the bench reports failures, so this script
# greps the log: it passes only if "TEST PASSED" is present and no
# "FAIL" line was printed.

set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${1:-$DESIGN_DIR/work/sim}

mkdir -p "$WORK_DIR"

echo "=== Simulation: intel_4001 ==="
echo "  Design dir: $DESIGN_DIR"
echo "  Work dir:   $WORK_DIR"

SRC_FILES=$(find "$DESIGN_DIR/src" "$DESIGN_DIR/tb" -name "*.sv" | sort)
echo "  Sources:"
for f in $SRC_FILES; do
    echo "    $f"
done

if ! xezim --simulate \
    -s tb_intel_4001 \
    -I "$DESIGN_DIR/src" \
    -I "$DESIGN_DIR/tb" \
    --fst "$WORK_DIR/tb.fst" \
    --max-time 1000000000 \
    -l "$WORK_DIR/tb.log" \
    $SRC_FILES; then
    echo "  ERROR: xezim exited nonzero"
    tail -40 "$WORK_DIR/tb.log" || true
    exit 1
fi

if grep -q "TEST PASSED" "$WORK_DIR/tb.log" && ! grep -q "FAIL" "$WORK_DIR/tb.log"; then
    echo "=== Simulation PASSED ==="
    grep -E "4001 tb:|TEST PASSED" "$WORK_DIR/tb.log"
    exit 0
else
    echo "=== Simulation FAILED ==="
    grep -E "FAIL|TEST" "$WORK_DIR/tb.log" | head -50 || true
    exit 1
fi
