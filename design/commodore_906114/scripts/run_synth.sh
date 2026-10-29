#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv $HERE/src/commodore_906114.sv; synth -top commodore_906114 -flatten; check -assert; stat; write_json $HERE/work/synth/commodore_906114.json" \
    > "$HERE/work/synth/yosys.log" 2>&1
grep -A12 'Number of cells' "$HERE/work/synth/yosys.log" | head -14
echo 'COMMODORE 906114 SYNTHESIS PASS'
