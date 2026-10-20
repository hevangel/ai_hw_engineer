#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/run_timer_formal.sh"
sh "$HERE/scripts/run_timer_reference.sh"
sh "$HERE/scripts/run_timer_fourstate.sh"
sh "$HERE/scripts/run_timer_synth.sh"
echo 'MOS 6526 TIMER FOUNDATION GATES PASS (full CIA still required)'
