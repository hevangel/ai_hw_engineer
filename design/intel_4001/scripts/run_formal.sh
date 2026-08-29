#!/bin/bash
# Run formal verification with SymbiYosys.
# Usage: ./run_formal.sh [bmc|prove|cover|all]
#
# SymbiYosys resolves [files] paths against the invocation directory, so
# sby is run from formal/ where the ../src reference is valid.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
FORMAL_DIR="$DESIGN_DIR/formal"
WORK_DIR="$DESIGN_DIR/work/formal"

TASK=${1:-all}

mkdir -p "$WORK_DIR"

run_task() {
    task="$1"
    echo "--- sby $task ---"
    if (cd "$FORMAL_DIR" && sby -f -d "$WORK_DIR/intel_4001_$task" \
            intel_4001.sby "$task" > "$WORK_DIR/intel_4001_$task.log" 2>&1); then
        echo "  PASS: intel_4001 ($task)"
        grep -E "Reached cover|Unreached|DONE" \
            "$WORK_DIR/intel_4001_$task.log" | tail -5 || true
        return 0
    else
        echo "  FAIL: intel_4001 ($task)"
        tail -40 "$WORK_DIR/intel_4001_$task.log" || true
        return 1
    fi
}

echo "=== Formal verification: intel_4001 ==="

STATUS=0
if [ "$TASK" = "all" ]; then
    run_task bmc || STATUS=1
    run_task prove || STATUS=1
    run_task cover || STATUS=1
else
    run_task "$TASK" || STATUS=1
fi

if [ $STATUS -eq 0 ]; then
    echo "=== Formal: ALL PASSED ==="
else
    echo "=== Formal: FAILED ==="
fi
exit $STATUS
