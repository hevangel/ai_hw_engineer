#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
echo "=== am29332: transcription guard (worked examples vs model) ==="
python3 "$SCRIPT_DIR/generate_oracle.py" --check-table
echo "=== am29332: lint ==="
verilator --lint-only -Wall --top-module amd_am29332 "$DESIGN_DIR/src/amd_am29332.sv"
echo "=== am29332: formal (bmc, prove, cover) ==="
sh "$SCRIPT_DIR/run_formal.sh"
echo "=== am29332: lockstep simulation ==="
sh "$SCRIPT_DIR/run_sim.sh"
echo "=== am29332: synthesis ==="
sh "$SCRIPT_DIR/run_synth.sh" > /dev/null
echo "=== am29332: all gates passed ==="
