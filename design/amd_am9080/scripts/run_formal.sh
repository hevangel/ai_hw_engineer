#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/formal"
cd "$DESIGN_DIR/formal"
for design in amd_am9080_alu amd_am9080; do
    for task in bmc prove cover; do
        echo "=== Am9080A formal: $design $task ==="
        sby -f -d "$DESIGN_DIR/work/formal/${design}_$task" "$design.sby" "$task"
    done
done
