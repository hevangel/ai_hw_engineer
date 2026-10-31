#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
xezim --simulate --sv2017 --error-exit -s tb_tod "$HERE/src/mos_6526_tod.sv" \
    "$HERE/tb/tb_tod.sv" --max-time 100000ns -l "$HERE/work/tod-fourstate.log"
grep 'MOS 6526 TOD FOUR-STATE PASS:' "$HERE/work/tod-fourstate.log"
