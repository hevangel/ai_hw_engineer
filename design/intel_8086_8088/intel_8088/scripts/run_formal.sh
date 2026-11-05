#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/formal"
cd "$DESIGN_DIR/formal"
for task in bmc prove cover; do
    echo "=== Intel 8088 formal: intel_8088_biu $task ==="
    sby -f -d "$DESIGN_DIR/work/formal/intel_8088_biu_$task" intel_8088_biu.sby "$task"
done
