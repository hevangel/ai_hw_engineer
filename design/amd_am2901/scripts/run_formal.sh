#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/formal"
cd "$DESIGN_DIR/formal"
for module in amd_am2901_alu amd_am2901; do
    for task in bmc prove cover; do
        sby -f -d "$DESIGN_DIR/work/formal/${module}_${task}" "$module.sby" "$task"
    done
done
