#!/bin/sh
# Run SymbiYosys for both timer variants.
# Usage: run_formal.sh [all|bmc|prove|cover|cover_8253|<exact-task>]
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
        sby -f -d "$WORK_DIR/$task_name" intel_8253_8254.sby "$task_name"
    )
}

run_8253_cover() {
    run_task cover_8253_mode0
    run_task cover_8253_mode1
    run_task cover_8253_mode2
    run_task cover_8253_bus_reset_readback
}

case "$TASK" in
    bmc)
        run_task bmc_8253
        run_task bmc_8254
        ;;
    prove)
        run_task prove_8253
        run_task prove_8254
        ;;
    cover)
        run_8253_cover
        run_task cover_8254
        ;;
    cover_8253)
        run_8253_cover
        ;;
    bmc_8253|prove_8253|cover_8253_mode0|cover_8253_mode1|cover_8253_mode2|cover_8253_bus_reset_readback|bmc_8254|prove_8254|cover_8254)
        run_task "$TASK"
        ;;
    all)
        run_task bmc_8253
        run_task prove_8253
        run_8253_cover
        run_task bmc_8254
        run_task prove_8254
        run_task cover_8254
        ;;
    *)
        echo "ERROR: unsupported formal task '$TASK'" >&2
        exit 2
        ;;
esac

echo "=== Formal verification passed: $TASK ==="
