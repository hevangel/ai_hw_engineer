#!/bin/sh
# Complete ricoh_2c02 chip flow. Real-software regressions (blargg PPU ROMs,
# nestest) run in system/nes/scripts/run_all.sh with the 2A03 and board.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/run_lint.sh"
sh "$HERE/scripts/run_sim.sh"
sh "$HERE/scripts/run_formal.sh"
sh "$HERE/scripts/run_synth.sh"
echo 'RICOH 2C02 ALL PASS'
