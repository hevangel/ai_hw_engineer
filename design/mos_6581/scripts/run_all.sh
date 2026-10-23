#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$HERE/run_sid_formal.sh"
sh "$HERE/run_sid_sim.sh"
sh "$HERE/run_sid_mutants.sh"
sh "$HERE/run_sid_synth.sh"
echo 'MOS 6581/8580 SID digital-core gates passed; analog filter/DAC stage and original software remain open.'
