#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
echo '=== motorola_6800: lint ==='
sh "$SCRIPT_DIR/run_lint.sh"
echo '=== motorola_6800: simulation (ISS vectors + full ISA) ==='
sh "$SCRIPT_DIR/run_sim.sh"
echo '=== motorola_6800: third-party test programs ==='
sh "$SCRIPT_DIR/run_software.sh"
echo '=== motorola_6800: formal ==='
sh "$SCRIPT_DIR/run_formal.sh"
echo '=== motorola_6800: synthesis ==='
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== motorola_6800 complete verification PASSED ==='
