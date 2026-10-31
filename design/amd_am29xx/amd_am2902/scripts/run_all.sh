#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/lint"
verilator --lint-only -Wall --top-module amd_am2902 "$DESIGN_DIR/src/amd_am2902.sv" > "$DESIGN_DIR/work/lint/rtl.log" 2>&1
verilator --lint-only -Wall --timing --top-module tb_top "$DESIGN_DIR/src/amd_am2902.sv" \
    "$DESIGN_DIR/../amd_am2901/src/amd_am2901_alu.sv" "$DESIGN_DIR/tb/tb_top.sv" > "$DESIGN_DIR/work/lint/tb.log" 2>&1
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== Am2902 complete verification PASSED ==='
