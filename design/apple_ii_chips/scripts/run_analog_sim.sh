#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
iverilog -g2012 -s tb_analog -o work/analog.vvp src/analog/*.sv tb/tb_analog.sv
vvp work/analog.vvp >work/analog.log 2>&1 || { cat work/analog.log; exit 1; }
cat work/analog.log
grep -q 'PASS analog' work/analog.log
