#!/bin/sh
# Run the complete 74181 sign-off flow inside ai-hw-engineer:latest.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

sh "$SCRIPT_DIR/run_74181_lint.sh"
sh "$SCRIPT_DIR/run_74181_sim.sh" all
sh "$SCRIPT_DIR/run_74181_formal.sh" all
sh "$SCRIPT_DIR/run_74181_synth.sh"

echo "=== alu_74181 sign-off flow passed ==="
