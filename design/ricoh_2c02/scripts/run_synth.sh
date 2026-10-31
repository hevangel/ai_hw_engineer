#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/scripts/sources.sh"
mkdir -p "$HERE/work/synth"
for region in 0 1; do
    yosys -Q -p "read_verilog -sv $RICOH_2C02_SRC; chparam -set REGION $region ricoh_2c02; synth -top ricoh_2c02 -flatten; check -assert; stat" \
        > "$HERE/work/synth/yosys-region$region.log" 2>&1 || { tail -30 "$HERE/work/synth/yosys-region$region.log"; exit 1; }
done
echo 'RICOH 2C02 SYNTHESIS PASS'
