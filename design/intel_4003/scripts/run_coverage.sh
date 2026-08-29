#!/bin/sh
# Run the formal cover task (non-vacuity proof) and summarize the cover
# results inside ai-hw-engineer:latest. Usage: run_coverage.sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
FORMAL_DIR="$DESIGN_DIR/formal"
WORK_DIR="$DESIGN_DIR/work/formal"

mkdir -p "$WORK_DIR"

echo "=== SymbiYosys cover (non-vacuity): intel_4003 ==="
(
    cd "$FORMAL_DIR"
    sby -f -d "$WORK_DIR/cover" intel_4003.sby cover
)

COVER_LOG="$WORK_DIR/cover/logfile.txt"
if [ ! -f "$COVER_LOG" ]; then
    echo "ERROR: cover log not found: $COVER_LOG" >&2
    exit 1
fi

# Reachable covers are reported one per line; require the pass summary.
grep -q "Reached cover statement" "$COVER_LOG"
COVER_COUNT=$(grep -c "Reached cover statement" "$COVER_LOG" || true)

echo "=== Formal cover summary: intel_4003 ==="
echo "  Reached covers: $COVER_COUNT"
echo "  Log: $COVER_LOG"

if [ "$COVER_COUNT" -lt 33 ]; then
    echo "ERROR: expected at least 33 reachable covers, got $COVER_COUNT" >&2
    exit 1
fi

echo "=== Cover verification passed ==="
