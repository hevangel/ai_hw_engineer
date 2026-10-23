#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
for variant in ${1:-0 1 2 3 4}; do
    yosys -Q -T -p "read_verilog -sv $HERE/src/mos_6567.sv; chparam -set VARIANT $variant mos_6567; synth -top mos_6567; check -assert; stat" \
        > "$HERE/work/vicii-synth-$variant.log" 2>&1
    echo "== VARIANT=$variant"
    grep -E "^ +[0-9]+ cells$" "$HERE/work/vicii-synth-$variant.log" | tail -1
    grep "Found and reported 0 problems" "$HERE/work/vicii-synth-$variant.log" | tail -1
done
