#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
echo "=== Apple 6502 generic synthesis ==="
yosys -Q -q -l "$HERE/work/synth/synth.log" -p "read_verilog -sv $HERE/src/mos_6502.sv; hierarchy -check -top mos_6502; synth -top mos_6502; check -assert; stat; write_json $HERE/work/synth/mos_6502.json; write_verilog -noattr $HERE/work/synth/mos_6502.v"
echo "Apple 6502 SYNTHESIS PASSED; log: $HERE/work/synth/synth.log"
