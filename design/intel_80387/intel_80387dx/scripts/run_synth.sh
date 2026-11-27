#!/bin/sh
set -eu
D=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
X=$(CDPATH= cd -- "$D/../../intel_8087/src" && pwd)
mkdir -p "$D/work/synth"
yosys -Q -T -p "read_verilog -sv -I$X $X/intel_8087_alu.sv $X/intel_8087_trans.sv $X/intel_8087.sv; chparam -set VARIANT 2 -set AW 32 intel_8087; hierarchy -check -top intel_8087; proc; opt; check -assert; stat" > "$D/work/synth/yosys.log" 2>&1
echo 'PASS Intel 80387 synthesis elaboration (VARIANT=2)'
