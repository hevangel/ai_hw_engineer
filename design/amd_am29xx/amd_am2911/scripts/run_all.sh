#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/lint"
verilator --lint-only -Wall --top-module amd_am2911 "$DESIGN_DIR/../amd_am2909/src/amd_am2909.sv" "$DESIGN_DIR/src/amd_am2911.sv" > "$DESIGN_DIR/work/lint/rtl.log" 2>&1
verilator --lint-only -Wall --top-module tb_top "$DESIGN_DIR/../amd_am2909/src/amd_am2909.sv" "$DESIGN_DIR/src/amd_am2911.sv" "$DESIGN_DIR/tb/tb_top.sv" > "$DESIGN_DIR/work/lint/tb.log" 2>&1
sh "$SCRIPT_DIR/run_formal.sh"
# Includes actual manufacturer Figures 7/8 software and exact next-PC checks.
sh "$SCRIPT_DIR/run_software.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== Am2911 complete verification PASSED ==='
