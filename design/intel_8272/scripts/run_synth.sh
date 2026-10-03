#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
for top in intel_8272 intel_8272_codec intel_8272_crc; do
  yosys -Q -q -l "$HERE/work/synth/$top.log" -p "read_verilog -sv $HERE/src/$top.sv; hierarchy -check -top $top; synth -top $top; check -assert; stat; write_json $HERE/work/synth/$top.json; write_verilog -noattr $HERE/work/synth/$top.v"
done
echo '8272 SYNTHESIS PASSED'
