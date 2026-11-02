#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$HERE/run_lint.sh"
sh "$HERE/run_formal.sh" all
sh "$HERE/run_sim.sh" "${1:-1}"
sh "$HERE/run_coverage.sh"
sh "$HERE/run_synth.sh"
# Cross-core differential: the same program on both 6502 implementations, with
# architectural state compared at every fetch (review item C3).
sh "$HERE/../compare/run.sh"
sh "$HERE/../compare/negative_control.sh"
echo "Apple 6502 COMPLETE FLOW PASSED"
