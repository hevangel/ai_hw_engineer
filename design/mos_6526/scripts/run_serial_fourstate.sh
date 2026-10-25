#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
verilator --binary --timing -Wall -Wno-TIMESCALEMOD -j 4 --top-module tb_serial \
    --Mdir "$HERE/work/serial-sv" "$HERE/src/mos_6526_serial.sv" "$HERE/tb/tb_serial.sv" \
    > "$HERE/work/serial-sv-build.log" 2>&1
"$HERE/work/serial-sv/Vtb_serial" > "$HERE/work/serial-sv.log" 2>&1
grep 'MOS 6526 SERIAL FOUR-STATE PASS:' "$HERE/work/serial-sv.log"
xezim --simulate --sv2017 --error-exit -s tb_serial "$HERE/src/mos_6526_serial.sv" \
    "$HERE/tb/tb_serial.sv" --max-time 200000ns -l "$HERE/work/serial-fourstate.log"
grep 'MOS 6526 SERIAL FOUR-STATE PASS:' "$HERE/work/serial-fourstate.log"
