#!/bin/sh
# Run the complete 74181 sign-off flow inside ai-hw-engineer:latest.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

"$SCRIPT_DIR/run_lint.sh"
"$SCRIPT_DIR/run_sim.sh" all
"$SCRIPT_DIR/run_formal.sh" all
"$SCRIPT_DIR/run_synth.sh"

echo "=== alu_74181 sign-off flow passed ==="
