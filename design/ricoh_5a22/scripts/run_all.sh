#!/bin/sh
# Complete RICOH 5A22 flow: lint, independent-oracle gate, synthesis.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/run_lint.sh"
sh "$HERE/scripts/run_test.sh"
sh "$HERE/scripts/run_synth.sh"
echo 'RICOH 5A22 ALL PASS'
