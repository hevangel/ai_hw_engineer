#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
for model in 0 1; do
    yosys -Q -T -p "read_verilog -sv $HERE/src/mos_6581.sv; chparam -set MOS8580 $model mos_6581; synth -top mos_6581; check -assert; stat" \
        > "$HERE/work/sid-synth-$model.log" 2>&1
    echo "== MOS8580=$model"
    grep -E "^ +[0-9]+ cells$" "$HERE/work/sid-synth-$model.log" | tail -1
    grep "Found and reported 0 problems" "$HERE/work/sid-synth-$model.log" | tail -1
done
