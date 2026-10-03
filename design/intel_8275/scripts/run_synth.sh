#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
yosys -Q -q -l "$HERE/work/synth/synth.log" -p "read_verilog -sv $HERE/src/intel_8275.sv; hierarchy -check -top intel_8275; synth -top intel_8275; check -assert; stat; write_json $HERE/work/synth/netlist.json; write_verilog -noattr $HERE/work/synth/netlist.v"
echo '8275 SYNTHESIS PASSED'
