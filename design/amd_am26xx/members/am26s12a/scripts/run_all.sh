#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$SCRIPT_DIR/run_lint.sh"
sh "$SCRIPT_DIR/run_formal.sh" all
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo "Am26S12A COMPLETE FLOW PASSED"
