#!/bin/sh
# Generic Yosys synthesis and structural check of the RICOH 5C78 RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv  "$HERE/src/ricoh_5c78.sv"; synth -top ricoh_5c78 -flatten; check -assert; stat" \
    > "$HERE/work/synth/yosys.log" 2>&1 || { tail -30 "$HERE/work/synth/yosys.log"; exit 1; }
grep -E "Number of cells" "$HERE/work/synth/yosys.log" | tail -1
echo 'RICOH 5C78 SYNTHESIS PASS'
