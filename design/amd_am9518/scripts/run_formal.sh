#!/bin/sh
# Run formal verification with SymbiYosys (bmc, prove, cover tasks).
#
# Usage: sh design/amd_am9518/scripts/run_formal.sh [task]
#   With no argument, runs all three tasks in sequence and fails if any
#   task fails.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/formal"

mkdir -p "$WORK_DIR"

echo "=== SymbiYosys: amd_am9518 ==="

# sby resolves [files] entries relative to the current directory, so run
# from the design folder (matching the ../src/ entries in the .sby file).
cd "$DESIGN_DIR"

if [ "$#" -gt 0 ]; then
    sby -f -d "$WORK_DIR/amd_am9518_$1" formal/amd_am9518.sby "$1"
    exit 0
fi

STATUS=0
for TASK in bmc prove cover; do
    echo "--- task: $TASK ---"
    if sby -f -d "$WORK_DIR/amd_am9518_$TASK" formal/amd_am9518.sby "$TASK"; then
        echo "--- $TASK PASS ---"
    else
        echo "--- $TASK FAIL ---"
        STATUS=1
    fi
done

if [ "$STATUS" -ne 0 ]; then
    echo "=== formal FAILED ==="
    exit 1
fi
echo "=== formal complete: all tasks passed ==="
