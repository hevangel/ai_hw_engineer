#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/formal"
cd "$DESIGN_DIR/formal"
for task in bmc prove cover; do
    sby -f -d "$DESIGN_DIR/work/formal/$task" amd_am2902.sby "$task"
done
