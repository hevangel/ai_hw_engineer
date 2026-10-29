#!/bin/sh
# Complete ricoh_2a03 chip flow. Real-software regressions (nestest, blargg
# APU/CPU ROMs) run in system/nes/scripts/run_all.sh with the 2C02 and board.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/run_lint.sh"
sh "$HERE/scripts/run_sim.sh"
sh "$HERE/scripts/run_cpu_vectors.sh"
sh "$HERE/scripts/run_formal.sh"
sh "$HERE/scripts/run_synth.sh"
echo 'RICOH 2A03 ALL PASS'
