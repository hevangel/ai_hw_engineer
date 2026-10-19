#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/native/synth"
yosys -Q -p "read_verilog -sv $HERE/src/mos_6502_native.sv; synth -top mos_6502_native; check; stat; write_json $HERE/work/native/synth/native.json" \
    > "$HERE/work/native/synth/yosys.log" 2>&1
echo 'NATIVE NMOS SYNTHESIS PASS'
