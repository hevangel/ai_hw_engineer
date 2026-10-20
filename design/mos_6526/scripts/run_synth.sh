#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv $HERE/src/mos_6526.sv $HERE/src/mos_6526_timer.sv $HERE/src/mos_6526_tod.sv $HERE/src/mos_6526_serial.sv $HERE/src/mos_6526_irq.sv; synth -top mos_6526; check; stat; write_json $HERE/work/synth/chip.json" > "$HERE/work/synth/chip.log" 2>&1
echo 'MOS 6526 INTEGRATED SYNTHESIS PASS'
