#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
for profile in 0 1; do
    yosys -Q -T -p "read_verilog -sv $HERE/src/mos_6560_raster.sv; chparam -set PAL $profile mos_6560_raster; synth -top mos_6560_raster; check -assert; stat" \
        > "$HERE/work/raster-synth-$profile.log" 2>&1
    tail -n 24 "$HERE/work/raster-synth-$profile.log"
done
