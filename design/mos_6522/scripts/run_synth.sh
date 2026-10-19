#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
yosys -Q -l "$HERE/work/synth/yosys.log" -p \
    "read_verilog -sv $HERE/src/mos_6522.sv; synth -top mos_6522; check; stat; write_json $HERE/work/synth/mos_6522.json"
grep -q 'Found and reported 0 problems' "$HERE/work/synth/yosys.log"
