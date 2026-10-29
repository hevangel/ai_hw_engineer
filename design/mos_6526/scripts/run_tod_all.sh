#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/run_tod_formal.sh"
sh "$HERE/scripts/run_tod_sim.sh"
sh "$HERE/scripts/run_tod_fourstate.sh"
sh "$HERE/scripts/run_tod_synth.sh"
echo 'MOS 6526 TOD FOUNDATION GATES PASS (full CIA still required)'
