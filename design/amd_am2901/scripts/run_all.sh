#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/lint"
echo '=== Am2901 native slice and cascade lint ==='
# Disable DFG optimization to retain meaningful paths for native latch feedback
# diagnostics. Source waivers name only the complementary-latch state paths.
verilator --lint-only -Wall -fno-dfg --top-module amd_am2901 \
    "$DESIGN_DIR/src/amd_am2901_alu.sv" "$DESIGN_DIR/src/amd_am2901.sv" > "$DESIGN_DIR/work/lint/rtl.log" 2>&1
verilator --lint-only -Wall -fno-dfg --top-module tb_top \
    "$DESIGN_DIR/src/amd_am2901_alu.sv" "$DESIGN_DIR/src/amd_am2901.sv" "$DESIGN_DIR/tb/tb_top.sv" > "$DESIGN_DIR/work/lint/cascade.log" 2>&1
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_software.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== Am2901 complete verification PASSED ==='
