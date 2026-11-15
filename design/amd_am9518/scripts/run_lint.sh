#!/bin/sh
# Run lint checks on the Am9518 design (verilator).
#
# Usage: sh design/amd_am9518/scripts/run_lint.sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/"

mkdir -p "$WORK_DIR"

VERILATOR=${VERILATOR:-verilator}

echo "=== verilator --lint-only -Wall: amd_am9518 ==="
cd "$DESIGN_DIR"
"$VERILATOR" --lint-only -Wall \
    -Isrc \
    --top-module amd_am9518_top \
    src/amd_am9518_top.sv \
    "$@"

echo "=== lint clean ==="
