#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
xezim --simulate --sv2017 --error-exit -s tb_serial "$HERE/src/mos_6526_serial.sv" \
    "$HERE/tb/tb_serial.sv" --max-time 100000ns -l "$HERE/work/serial-fourstate.log"
grep 'MOS 6526 SERIAL FOUR-STATE PASS:' "$HERE/work/serial-fourstate.log"
