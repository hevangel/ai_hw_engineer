#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
for mask in 0 1; do
    yosys -Q -l "$HERE/work/synth/mask$mask.log" -p \
        "read_verilog -sv -I$HERE/src $HERE/src/mos_6530.sv $HERE/src/mos_6530_kim.sv; chparam -set SECOND $mask mos_6530_kim; synth -top mos_6530_kim -flatten; check; stat; write_json $HERE/work/synth/mask$mask.json"
    grep -q 'Found and reported 0 problems' "$HERE/work/synth/mask$mask.log"
done
