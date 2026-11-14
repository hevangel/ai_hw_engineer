#!/bin/sh
# Run coverage build + suites (verilator --coverage).
#
# Usage: sh design/amd_am9518/scripts/run_coverage.sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/coverage"
OBJ_DIR="$WORK_DIR/obj_dir"

mkdir -p "$WORK_DIR"

VERILATOR=${VERILATOR:-verilator}

"$VERILATOR" \
    --cc --exe --build -j 0 -O2 \
    --coverage \
    --top-module amd_am9518_top \
    --Mdir "$OBJ_DIR" -I"$DESIGN_DIR/src" \
    "$DESIGN_DIR/src/des_core.sv" \
    "$DESIGN_DIR/src/amd_am9518_top.sv" \
    "$DESIGN_DIR/tb/amd_am9518_harness.cpp" \
    -o amd_am9518_cov

"$OBJ_DIR/amd_am9518_cov" --vectors "$DESIGN_DIR/tb/vectors" \
    "+verilator+coverage+file+$WORK_DIR/coverage0.dat"

verilator_coverage --write "$WORK_DIR/coverage.info" "$WORK_DIR"/coverage*.dat
verilator_coverage --annotate "$WORK_DIR/annotated" "$WORK_DIR"/coverage*.dat

echo "=== coverage written to $WORK_DIR/coverage.info ==="
