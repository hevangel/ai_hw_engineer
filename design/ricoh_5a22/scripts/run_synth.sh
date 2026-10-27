#!/bin/sh
# Generic Yosys synthesis and structural check of the RICOH 5A22 RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv  "$HERE/src/ricoh_5a22.sv" "$D/wdc_65c816/src/wdc_65c816.sv"; synth -top ricoh_5a22 -flatten; check -assert; stat" \
    > "$HERE/work/synth/yosys.log" 2>&1 || { tail -30 "$HERE/work/synth/yosys.log"; exit 1; }
grep -E "Number of cells" "$HERE/work/synth/yosys.log" | tail -1
echo 'RICOH 5A22 SYNTHESIS PASS'
