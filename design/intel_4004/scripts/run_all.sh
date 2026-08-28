#!/bin/sh
# Run the complete Intel 4004 verification and synthesis flow.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

echo "=== Intel 4004 complete flow ==="
sh "$SCRIPT_DIR/run_lint.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_formal.sh" all
sh "$SCRIPT_DIR/run_synth.sh"
echo "=== Intel 4004 complete flow passed ==="
