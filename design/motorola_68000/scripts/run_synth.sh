#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
echo '=== MC68000 generic synthesis ==='
yosys -Q -q -l "$HERE/work/synth/synth.log" -p "read_verilog -sv $HERE/src/motorola_68000.sv; hierarchy -check -top motorola_68000; synth -top motorola_68000; check -assert; stat; write_json $HERE/work/synth/motorola_68000.json"
echo 'MC68000 SYNTHESIS PASSED; log: work/synth/synth.log'
