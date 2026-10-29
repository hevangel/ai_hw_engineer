#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv $HERE/src/mos_6526_timer.sv; synth -top mos_6526_timer; check; stat; write_json $HERE/work/synth/timer.json" \
    > "$HERE/work/synth/timer.log" 2>&1
echo 'MOS 6526 TIMER SYNTHESIS PASS'
