#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/formal"
cd "$DESIGN_DIR/formal"
for task in bmc prove cover; do
    echo "Formal $task"
    sby -f -d "$DESIGN_DIR/work/formal/$task" amd_am9513.sby "$task"
done