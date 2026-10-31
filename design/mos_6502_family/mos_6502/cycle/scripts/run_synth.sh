#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work/synth
yosys -Q -T -p 'read_verilog -sv src/mos_6502_cycle.sv; synth -top mos_6502_cycle; check -assert; stat; write_json work/synth/mos_6502_cycle.json' >work/synth/synthesis.log 2>&1 || { cat work/synth/synthesis.log; exit 1; }
tail -n 25 work/synth/synthesis.log
