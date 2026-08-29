#!/bin/sh
# Run formal verification with SymbiYosys.
# Usage: ./run_formal.sh [bmc|prove|cover|all]
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
FORMAL_DIR="$DESIGN_DIR/formal"
WORK_DIR="$DESIGN_DIR/work/formal"

TASK=${1:-all}

mkdir -p "$WORK_DIR"

run_task() {
    task="$1"
    # SymbiYosys resolves [files] paths against the invocation directory,
    # so run from formal/ where the ../src references are valid.
    (cd "$FORMAL_DIR" && sby -f -d "$WORK_DIR/intel_4004_$task" \
        intel_4004.sby "$task" > "$WORK_DIR/intel_4004_$task.log" 2>&1)
}

echo "=== Formal verification: Intel 4004 ==="

if [ "$TASK" = "all" ]; then
    run_task bmc
    run_task prove
    run_task cover
else
    run_task "$TASK"
fi

echo "=== Formal verification passed ==="
echo "Logs: $WORK_DIR"
