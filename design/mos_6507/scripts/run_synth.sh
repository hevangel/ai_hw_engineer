#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv $HERE/../mos_6502_family/mos_6502/src/mos_6502_native.sv $HERE/src/mos_6507.sv; synth -top mos_6507 -flatten; check; stat; write_json $HERE/work/synth/mos_6507.json" \
    > "$HERE/work/synth/yosys.log" 2>&1
echo 'MOS 6507 SYNTHESIS PASS'
