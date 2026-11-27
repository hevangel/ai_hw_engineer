#!/bin/sh
# Milestone M1 release gate for the Intel 80386 core: lint, formal,
# physical-capture replay and synthesis. The historical-software gate is
# not yet present (see report/final_report.md); this script says so.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
echo ">>> Lint";      sh "$SCRIPT_DIR/run_lint.sh"
echo ">>> Formal";    sh "$SCRIPT_DIR/run_formal.sh"
echo ">>> Replay";    sh "$SCRIPT_DIR/run_vectors.sh"
echo ">>> Synthesis"; sh "$SCRIPT_DIR/run_synth.sh"
echo "NOTE: no original-software regression exists yet for the 80386 (open M1 gate)."
echo "=== M1 gate steps completed ==="
