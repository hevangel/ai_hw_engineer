#!/bin/sh
# Run SymbiYosys tasks inside ai-hw-engineer:latest.
# Usage: run_formal.sh [all|bmc|prove|cover]
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
FORMAL_DIR="$DESIGN_DIR/formal"
WORK_DIR="$DESIGN_DIR/work/formal"
TASK=${1:-all}

mkdir -p "$WORK_DIR"

run_task() {
    task_name=$1
    echo "=== SymbiYosys: $task_name ==="
    (
        cd "$FORMAL_DIR"
        sby -f -d "$WORK_DIR/$task_name" intel_4003.sby "$task_name"
    )
}

case "$TASK" in
    bmc|prove|cover)
        run_task "$TASK"
        ;;
    all)
        run_task bmc
        run_task prove
        run_task cover
        ;;
    *)
        echo "ERROR: expected all, bmc, prove, or cover; got '$TASK'" >&2
        exit 2
        ;;
esac

echo "=== Formal verification passed: $TASK ==="
