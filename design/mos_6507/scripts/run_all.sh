#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
# Includes the historical Klaus test, not just instruction-level agreement.
sh "$HERE/../mos_6502_family/mos_6502/scripts/run_native_all.sh"
sh "$HERE/scripts/run_lint.sh"
sh "$HERE/scripts/run_formal.sh"
# Also executes the original KIM monitor on the actual reduced address bus.
sh "$HERE/scripts/run_sim.sh"
sh "$HERE/scripts/run_synth.sh"
echo 'MOS 6507 ALL GATES PASS'
