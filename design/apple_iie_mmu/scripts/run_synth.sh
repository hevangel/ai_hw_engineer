#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
echo "=== Apple IIe MMU generic synthesis ==="
yosys -Q -q -l "$HERE/work/synth/synth.log" -p "read_verilog -sv $HERE/src/apple_iie_mmu.sv; hierarchy -check -top apple_iie_mmu; synth -top apple_iie_mmu; check -assert; stat; write_json $HERE/work/synth/apple_iie_mmu.json; write_verilog -noattr $HERE/work/synth/apple_iie_mmu.v"
echo "Apple IIe MMU SYNTHESIS PASSED; log: $HERE/work/synth/synth.log"
