#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python3 "$SCRIPT_DIR/generate_commands.py" --check
python3 "$SCRIPT_DIR/generate_derived_constants.py" --check
python3 "$SCRIPT_DIR/generate_formal_stack.py" --check
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo "TEST PASSED: Am9511 complete verification flow"
