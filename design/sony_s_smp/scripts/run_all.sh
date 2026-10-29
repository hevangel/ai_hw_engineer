#!/bin/sh
# Complete SONY S-SMP flow: lint, independent-oracle gate, synthesis.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/run_lint.sh"
sh "$HERE/scripts/run_smp_test.sh"
sh "$HERE/scripts/run_synth.sh"
echo 'SONY S-SMP ALL PASS'
