#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
# Check the zero-delay combinational logic subset only. Analog, DRAM event
# models, and external transistor solver are simulation components.
for part in 74ls00 74ls02 74ls04 74ls08 74ls11 74ls20 74ls32 74ls51 74ls86 \
            74ls138 74ls139 74ls151 74ls153 74ls251 74ls257 74ls283; do
    top="a2_$part"
    echo "Synthesizing $top"
    yosys -Q -T -p "read_verilog -sv src/$top.sv; hierarchy -check -top $top; synth -top $top; check -assert" \
        >"work/synth_$part.log" 2>&1 || { cat "work/synth_$part.log"; exit 1; }
done
echo 'PASS synthesis of 16 combinational package models'
