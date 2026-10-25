#!/bin/bash
# Run formal verification with SymbiYosys
# Usage: ./run_formal.sh [task]
#   task: bmc | prove | cover (default: all three, in that order)
#
# NOTE: sby resolves the [files] paths in the .sby file relative to the
# CURRENT WORKING DIRECTORY, so this script always cds into formal/ before
# invoking sby (running it from anywhere else fails to find ../src/*.sv).

set -e

DESIGN_DIR=$(dirname $(dirname $(realpath $0)))
FORMAL_DIR=$DESIGN_DIR/formal
WORK_DIR=$DESIGN_DIR/work/formal
CHIP_NAME=$(basename $DESIGN_DIR)

TASK=${1:-""}

case "$TASK" in
    "")               TASKS="bmc prove cover" ;;
    bmc|prove|cover)  TASKS="$TASK" ;;
    *) echo "ERROR: unknown task '$TASK' (use bmc, prove, or cover)"; exit 1 ;;
esac

mkdir -p $WORK_DIR

echo "=== Running formal verification: $CHIP_NAME (tasks: $TASKS) ==="

SBY_FILE=$(find $FORMAL_DIR -maxdepth 1 -name "*.sby" | sort | head -1)
if [ -z "$SBY_FILE" ]; then
    echo "ERROR: No .sby files found in $FORMAL_DIR/"
    exit 1
fi

PASS_COUNT=0
FAIL_COUNT=0

cd $FORMAL_DIR
for t in $TASKS; do
    echo "--- Task: $t ---"
    if sby -f -d $WORK_DIR/$CHIP_NAME $SBY_FILE $t > $WORK_DIR/${t}_console.log 2>&1; then
        echo "  PASS: $t (log: $WORK_DIR/${t}_console.log)"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $t (log: $WORK_DIR/${t}_console.log)"
        tail -5 $WORK_DIR/${t}_console.log
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
fi
echo "  STATUS: ALL PASSED"
