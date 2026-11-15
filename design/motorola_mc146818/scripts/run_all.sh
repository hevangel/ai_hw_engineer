#!/bin/sh
# MC146818 complete flow from a clean work directory: lint, formal,
# simulation (model checks, directed, random, IBM AT BIOS replay),
# mutation check, synthesis. Exits nonzero on the first failure.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${MC146818_WORK_DIR:-$ROOT/work}
rm -rf "$WORK/formal" "$WORK/sim" "$WORK/mutation" "$WORK/synth.log" "$WORK/synth_stat.txt"
start=$(date +%s)
sh "$ROOT/scripts/run_lint.sh"
sh "$ROOT/scripts/run_formal.sh"
sh "$ROOT/scripts/run_sim.sh" "$@"
sh "$ROOT/scripts/run_mutation.sh"
sh "$ROOT/scripts/run_synth.sh"
echo "PASS: motorola_mc146818 complete flow in $(( $(date +%s) - start )) s"
