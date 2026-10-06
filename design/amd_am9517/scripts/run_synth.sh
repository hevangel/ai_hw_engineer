#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
echo "=== Am9517 generic synthesis ==="
yosys -Q -q -l "$HERE/work/synth/synth.log" -p "read_verilog -sv $HERE/src/amd_am9517.sv; hierarchy -check -top amd_am9517; synth -top amd_am9517; check -assert; stat; write_json $HERE/work/synth/amd_am9517.json; write_verilog -noattr $HERE/work/synth/amd_am9517.v"
echo "Am9517 SYNTHESIS PASSED; log: $HERE/work/synth/synth.log"
