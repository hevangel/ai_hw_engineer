#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$HERE/run_lint.sh"
sh "$HERE/run_formal.sh" all
sh "$HERE/run_sim.sh" "${1:-1}"
sh "$HERE/run_coverage.sh"
sh "$HERE/run_synth.sh"
echo '8272 COMPLETE FLOW PASSED'
