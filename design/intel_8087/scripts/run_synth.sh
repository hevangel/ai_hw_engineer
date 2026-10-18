#!/bin/sh
set -eu
D=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$D/work/synth"
echo 'Intel 8087: Yosys synthesizable RTL elaboration and cell checks'
yosys -Q -T -p "read_verilog -sv -I$D/src $D/src/intel_8087_alu.sv $D/src/intel_8087_trans.sv $D/src/intel_8087.sv; hierarchy -check -top intel_8087; proc; opt; check -assert; stat; write_json $D/work/synth/intel_8087.json" > "$D/work/synth/yosys.log" 2>&1
echo 'PASS Intel 8087 synthesis elaboration (technology-independent word-level netlist)'
