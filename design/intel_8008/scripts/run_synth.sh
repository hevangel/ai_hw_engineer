#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
yosys -Q -T -q -p "read_verilog -sv $ROOT/src/intel_8008.sv; synth -top intel_8008; check -assert"
echo "Intel 8008 Yosys synthesis passed"
