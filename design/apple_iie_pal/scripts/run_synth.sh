#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
echo "=== Apple IIe PAL generic synthesis ==="
yosys -Q -q -l "$HERE/work/synth/synth.log" -p "read_verilog -sv $HERE/src/apple_iie_pal.sv; hierarchy -check -top apple_iie_pal; synth -top apple_iie_pal; check -assert; stat; write_json $HERE/work/synth/apple_iie_pal.json; write_verilog -noattr $HERE/work/synth/apple_iie_pal.v"
echo "Apple IIe PAL SYNTHESIS PASSED; log: $HERE/work/synth/synth.log"
