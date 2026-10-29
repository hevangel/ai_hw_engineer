#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/run_serial_formal.sh"
sh "$HERE/scripts/run_serial_sim.sh"
sh "$HERE/scripts/run_serial_fourstate.sh"
sh "$HERE/scripts/run_serial_synth.sh"
echo 'MOS 6526 SERIAL FOUNDATION GATES PASS (full CIA still required)'
