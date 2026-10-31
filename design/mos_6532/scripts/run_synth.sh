#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
yosys -Q -l "$HERE/work/synth/yosys.log" -p \
    "read_verilog -sv $HERE/src/mos_6532.sv; synth -top mos_6532; check; stat; write_json $HERE/work/synth/mos_6532.json"
grep -q 'Found and reported 0 problems' "$HERE/work/synth/yosys.log"
