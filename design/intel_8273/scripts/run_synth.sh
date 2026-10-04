#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
for top in intel_8273 intel_8273_tx intel_8273_rx intel_8273_dpll; do
  yosys -Q -q -l "$HERE/work/synth/$top.log" -p "read_verilog -sv $HERE/src/intel_8273.sv $HERE/src/intel_8273_tx.sv $HERE/src/intel_8273_rx.sv $HERE/src/intel_8273_dpll.sv; hierarchy -check -top $top; synth -top $top; check -assert; stat; write_json $HERE/work/synth/$top.json; write_verilog -noattr $HERE/work/synth/$top.v"
done
echo '8273 SYNTHESIS PASSED'
