#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/lint"
python3 "$SCRIPT_DIR/generate_oracle.py" --check-table
verilator --lint-only -Wall --top-module amd_am29331 "$DESIGN_DIR/src/amd_am29331.sv" > "$DESIGN_DIR/work/lint/rtl.log" 2>&1
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== Am29331 complete verification PASSED ==='
