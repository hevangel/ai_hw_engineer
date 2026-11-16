#!/bin/sh
# IBM VGA complete flow from a clean work directory: lint, formal (with
# planted faults), simulation (ROM fetch/verify, directed, random with the
# coverage gate, BIOS mode-table geometry, static ROM I/O audit, Unicorn
# execution of the POST and INT 10h mode sets replayed on RTL and model,
# irregular clock enables), mutation check, synthesis. Exits nonzero on the
# first failure. work/refs and work/firmware are kept (downloads).
# Requires the Python packages capstone and unicorn (2.1.4) for the ROM
# stages: pip install unicorn==2.1.4 capstone
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${VGA_WORK_DIR:-$ROOT/work}
rm -rf "$WORK/formal" "$WORK/sim" "$WORK/mutation" "$WORK/synth.log" "$WORK/synth_stat.txt"
start=$(date +%s)
t() { echo "-- $1: $(( $(date +%s) - $2 )) s"; }
s=$(date +%s); sh "$ROOT/scripts/run_lint.sh"; t lint "$s"
s=$(date +%s); sh "$ROOT/scripts/run_formal.sh"; t formal "$s"
s=$(date +%s); sh "$ROOT/scripts/run_sim.sh" "$@"; t simulation "$s"
s=$(date +%s); sh "$ROOT/scripts/run_mutation.sh"; t mutation "$s"
s=$(date +%s); sh "$ROOT/scripts/run_synth.sh"; t synthesis "$s"
echo "PASS: ibm_vga complete flow in $(( $(date +%s) - start )) s"
