#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
TASK=${1:-all}
case "$TASK" in
    all) TASKS="bmc prove cover" ;;
    bmc|prove|cover) TASKS=$TASK ;;
    *) echo "ERROR: expected all, bmc, prove or cover" >&2; exit 2 ;;
esac
mkdir -p "$DESIGN_DIR/work/formal"
cd "$DESIGN_DIR/formal"
for task in $TASKS; do
    echo "=== Am9102 formal: $task ==="
    sby -f -d "$DESIGN_DIR/work/formal/$task" amd_am9102.sby "$task"
done
