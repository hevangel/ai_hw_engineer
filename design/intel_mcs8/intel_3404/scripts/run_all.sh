#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$HERE/run_lint.sh"
sh "$HERE/run_formal.sh" all
sh "$HERE/run_sim.sh"
sh "$HERE/run_coverage.sh"
sh "$HERE/run_synth.sh"
echo "Intel 3404 COMPLETE FLOW PASSED"
