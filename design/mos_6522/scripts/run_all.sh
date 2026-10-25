#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
echo '=== MOS 6522: lint, formal, simulation, synthesis ==='
sh "$HERE/run_lint.sh"
sh "$HERE/run_formal.sh"
sh "$HERE/run_sim.sh"
sh "$HERE/run_synth.sh"
echo '=== MOS 6522 complete flow passed ==='
