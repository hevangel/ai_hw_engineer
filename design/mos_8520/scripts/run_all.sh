#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$HERE/run_8520_formal.sh"
sh "$HERE/run_8520_sim.sh"
sh "$HERE/run_8520_synth.sh"
echo 'MOS 8520 digital gates passed; residual MAME classes and Amiga software qualification remain open.'
