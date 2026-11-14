#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/lint"
echo "=== Am26L02 Verilator lint (RTL, no waivers) ==="
verilator --lint-only -Wall --top-module am26l02 \
    "$DESIGN_DIR/src/am26l02.sv" > "$DESIGN_DIR/work/lint/rtl.log" 2>&1
echo "=== Am26L02 Verilator lint (TB waivers) ==="
verilator --lint-only -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL \
    --timing --top-module tb_top \
    "$DESIGN_DIR/src/am26l02.sv" "$DESIGN_DIR/tb/tb_top.sv" \
    > "$DESIGN_DIR/work/lint/tb.log" 2>&1
echo "Am26L02 LINT PASSED"
