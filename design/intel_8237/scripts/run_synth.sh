#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
echo "=== 8237A generic synthesis ==="
yosys -Q -q -l "$HERE/work/synth/synth.log" -p "read_verilog -sv $HERE/src/intel_8237.sv; hierarchy -check -top intel_8237; synth -top intel_8237; check -assert; stat; write_json $HERE/work/synth/intel_8237.json; write_verilog -noattr $HERE/work/synth/intel_8237.v"
echo "8237A SYNTHESIS PASSED; log: $HERE/work/synth/synth.log"
