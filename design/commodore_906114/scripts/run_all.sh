#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/run_lint.sh"
sh "$HERE/scripts/run_formal.sh"
sh "$HERE/scripts/run_sim.sh"
sh "$HERE/scripts/run_mutants.sh"
sh "$HERE/scripts/run_synth.sh"
echo 'COMMODORE 906114 ALL GATES PASS'
