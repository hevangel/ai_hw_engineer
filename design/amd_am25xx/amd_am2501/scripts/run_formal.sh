#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
TASK=${1:-all}
case "$TASK" in
    all) MODES="bmc prove cover" ;;
    bmc|prove|cover) MODES=$TASK ;;
    *) echo "ERROR: expected all, bmc, prove or cover" >&2; exit 2 ;;
esac
mkdir -p "$DESIGN_DIR/work/formal"
cd "$DESIGN_DIR/formal"
for enables in 6 2; do
    for mode in $MODES; do
        task="${mode}_${enables}"
        echo "=== Am2501 formal: $task ==="
        sby -f -d "$DESIGN_DIR/work/formal/$task" amd_am2501.sby "$task"
    done
done
