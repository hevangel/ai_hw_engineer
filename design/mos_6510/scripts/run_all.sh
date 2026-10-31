#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/../mos_6502_family/mos_6502/scripts/run_native_all.sh"
sh "$HERE/scripts/run_lint.sh"
sh "$HERE/scripts/run_formal.sh"
sh "$HERE/scripts/run_sim.sh"
sh "$HERE/scripts/run_synth.sh"
echo 'MOS 6510 ALL GATES PASS'
