#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/formal"
python3 "$SCRIPT_DIR/generate_oracle.py" --check-table
cd "$DESIGN_DIR/formal"
for task in bmc prove cover; do
    sby -f -d "$DESIGN_DIR/work/formal/$task" amd_am29331.sby "$task"
done
