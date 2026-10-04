#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/lint"
echo '=== Am9080A RTL Verilator -Wall lint ==='
verilator --lint-only -Wall --top-module amd_am9080 \
    "$DESIGN_DIR/src/amd_am9080_alu.sv" "$DESIGN_DIR/src/amd_am9080.sv" \
    > "$DESIGN_DIR/work/lint/rtl.log" 2>&1
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_alu.sh"
sh "$SCRIPT_DIR/run_units.sh"
sh "$SCRIPT_DIR/run_software.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== Am9080A complete verification PASSED ==='
