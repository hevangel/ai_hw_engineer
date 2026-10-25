#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
echo '=== motorola_6809: lint ==='
sh "$SCRIPT_DIR/run_lint.sh"
echo '=== motorola_6809: simulation (reyco2000 functional + interrupt) ==='
sh "$SCRIPT_DIR/run_sim.sh"
echo '=== motorola_6809: formal ==='
sh "$SCRIPT_DIR/run_formal.sh"
echo '=== motorola_6809: synthesis ==='
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== motorola_6809 complete verification PASSED ==='
