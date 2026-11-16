#!/bin/sh
# IBM EGA complete flow from a clean work directory: ROM fetch/verify,
# lint, formal, simulation (directed, random with coverage gate, BIOS mode
# geometry, BIOS replay), mutation check, synthesis. Exits nonzero on the
# first failure. work/refs and work/firmware are kept (downloads).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${EGA_WORK_DIR:-$ROOT/work}
rm -rf "$WORK/formal" "$WORK/sim" "$WORK/mutation" "$WORK/synth.log" "$WORK/synth_stat.txt"
start=$(date +%s)
t() { echo "-- $1: $(( $(date +%s) - $2 )) s"; }
s=$(date +%s); sh "$ROOT/scripts/run_lint.sh"; t lint "$s"
s=$(date +%s); sh "$ROOT/scripts/run_formal.sh"; t formal "$s"
s=$(date +%s); sh "$ROOT/scripts/run_sim.sh" "$@"; t simulation "$s"
s=$(date +%s); sh "$ROOT/scripts/run_mutation.sh"; t mutation "$s"
s=$(date +%s); sh "$ROOT/scripts/run_synth.sh"; t synthesis "$s"
echo "PASS: ibm_ega complete flow in $(( $(date +%s) - start )) s"
