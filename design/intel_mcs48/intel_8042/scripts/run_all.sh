#!/bin/sh
# Intel 8042 complete flow: lint, formal, lockstep simulation with the IBM
# firmware, synthesis.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$ROOT/scripts/run_lint.sh"
sh "$ROOT/scripts/run_formal.sh"
sh "$ROOT/scripts/run_sim.sh" "$@"
sh "$ROOT/scripts/run_synth.sh"
echo "PASS: intel_8042 complete flow"
