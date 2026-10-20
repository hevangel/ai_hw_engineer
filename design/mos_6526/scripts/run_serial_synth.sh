#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv $HERE/src/mos_6526_serial.sv; synth -top mos_6526_serial; check; stat; write_json $HERE/work/synth/serial.json" \
    > "$HERE/work/synth/serial.log" 2>&1
echo 'MOS 6526 SERIAL SYNTHESIS PASS'
