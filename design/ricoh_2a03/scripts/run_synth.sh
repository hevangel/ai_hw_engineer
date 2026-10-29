#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/scripts/sources.sh"
mkdir -p "$HERE/work/synth"
for region in 0 1; do
    yosys -Q -p "read_verilog -sv $RICOH_2A03_SRC; chparam -set REGION $region ricoh_2a03; synth -top ricoh_2a03 -flatten; check -assert; stat" \
        > "$HERE/work/synth/yosys-region$region.log" 2>&1 || { tail -30 "$HERE/work/synth/yosys-region$region.log"; exit 1; }
    grep -A1 'Number of cells' "$HERE/work/synth/yosys-region$region.log" | tail -2 | head -1
done
echo 'RICOH 2A03 SYNTHESIS PASS'
