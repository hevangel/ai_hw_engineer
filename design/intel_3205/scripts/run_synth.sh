#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
echo "=== Intel 3205 generic synthesis ==="
yosys -Q -q -l "$HERE/work/synth/synth.log" -p "read_verilog -sv $HERE/src/intel_3205.sv; hierarchy -check -top intel_3205; synth -top intel_3205; check -assert; stat; write_json $HERE/work/synth/intel_3205.json; write_verilog -noattr $HERE/work/synth/intel_3205.v"
echo "Intel 3205 SYNTHESIS PASSED; log: $HERE/work/synth/synth.log"
