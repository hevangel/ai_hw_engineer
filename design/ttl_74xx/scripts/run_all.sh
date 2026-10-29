#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python3 "$SCRIPT_DIR/run_library.py" inventory
python3 "$SCRIPT_DIR/check_provenance.py"
sh "$SCRIPT_DIR/run_lint.sh"
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_synth.sh"
python3 "$SCRIPT_DIR/write_library_report.py"
python3 "$SCRIPT_DIR/run_library.py" inventory --require-complete
echo "=== Numbered 74-series digital library complete ==="
