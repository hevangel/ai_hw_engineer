#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
echo '=== MC6809 generic synthesis ==='
yosys -Q -q -l "$HERE/work/synth/synth.log" -p "read_verilog -sv $HERE/src/motorola_6809.sv; hierarchy -check -top motorola_6809; synth -top motorola_6809; check -assert; stat; write_json $HERE/work/synth/motorola_6809.json"
echo 'MC6809 SYNTHESIS PASSED; log: work/synth/synth.log'
