#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv $HERE/src/mos_6526_tod.sv; synth -top mos_6526_tod; check; stat; write_json $HERE/work/synth/tod.json" \
    > "$HERE/work/synth/tod.log" 2>&1
echo 'MOS 6526 TOD SYNTHESIS PASS'
