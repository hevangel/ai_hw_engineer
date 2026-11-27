#!/bin/sh
set -eu
D=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$D/scripts/run_lint.sh"
sh "$D/scripts/run_formal.sh"
sh "$D/scripts/run_sim.sh"
sh "$D/scripts/run_synth.sh"
echo 'PASS Intel 80287 M1 architectural model; see report for limits'
