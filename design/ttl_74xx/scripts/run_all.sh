#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python3 "$SCRIPT_DIR/run_library.py" inventory
sh "$SCRIPT_DIR/run_lint.sh"
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_synth.sh"
python3 "$SCRIPT_DIR/write_library_report.py"
echo "=== Classic 7400-74299 digital library verification passed ==="
