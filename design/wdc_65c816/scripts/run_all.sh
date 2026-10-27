#!/bin/sh
# Complete WDC 65C816 flow: lint, independent-oracle gate, synthesis.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/run_lint.sh"
sh "$HERE/scripts/run_cpu_vectors.sh"
sh "$HERE/scripts/run_synth.sh"
echo 'WDC 65C816 ALL PASS'
