#!/bin/sh
# Generic Yosys synthesis and structural check of the WDC 65C816 RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv  "$HERE/src/wdc_65c816.sv"; synth -top wdc_65c816 -flatten; check -assert; stat" \
    > "$HERE/work/synth/yosys.log" 2>&1 || { tail -30 "$HERE/work/synth/yosys.log"; exit 1; }
grep -E "Number of cells" "$HERE/work/synth/yosys.log" | tail -1
echo 'WDC 65C816 SYNTHESIS PASS'
