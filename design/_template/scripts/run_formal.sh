#!/bin/bash
# Run formal verification with SymbiYosys
# Usage: ./run_formal.sh [task_name]

set -e

CHIP_NAME=$(basename $(dirname $(dirname $(realpath $0))))
DESIGN_DIR=$(dirname $(dirname $(realpath $0)))
WORK_DIR=$DESIGN_DIR/work/formal

# Create work directory
mkdir -p $WORK_DIR

echo "=== Running formal verification: $CHIP_NAME ==="

# Find .sby files
SBY_FILES=$(find $DESIGN_DIR/formal -name "*.sby" | sort)

if [ -z "$SBY_FILES" ]; then
    echo "ERROR: No .sby files found in $DESIGN_DIR/formal/"
    exit 1
fi

TASK=${1:-""}
PASS_COUNT=0
FAIL_COUNT=0

for sby_file in $SBY_FILES; do
    sby_name=$(basename $sby_file .sby)
    echo "--- Running: $sby_name $TASK ---"

    if sby -f -d $WORK_DIR/$sby_name $sby_file $TASK; then
        echo "  PASS: $sby_name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $sby_name"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo ""
echo "=== Formal verification summary ==="
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"

if [ $FAIL_COUNT -gt 0 ]; then
    echo "  STATUS: FAILED"
    exit 1
else
    echo "  STATUS: ALL PASSED"
fi
