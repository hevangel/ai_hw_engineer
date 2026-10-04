#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/lint"
python3 "$SCRIPT_DIR/generate_formal.py" --check
verilator --lint-only -Wall -fno-dfg --top-module amd_am2903 "$DESIGN_DIR/src/amd_am2903_datapath.sv" "$DESIGN_DIR/src/amd_am2903.sv" > "$DESIGN_DIR/work/lint/rtl.log" 2>&1
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_software.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== Am2903 complete verification PASSED ==='
