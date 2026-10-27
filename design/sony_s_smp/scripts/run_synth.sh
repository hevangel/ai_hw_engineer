#!/bin/sh
# Generic Yosys synthesis and structural check of the SONY S-SMP RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv  "$HERE/src/sony_s_smp.sv" "$D/sony_spc700/src/sony_spc700.sv"; synth -top sony_s_smp -flatten; check -assert; stat" \
    > "$HERE/work/synth/yosys.log" 2>&1 || { tail -30 "$HERE/work/synth/yosys.log"; exit 1; }
grep -E "Number of cells" "$HERE/work/synth/yosys.log" | tail -1
echo 'SONY S-SMP SYNTHESIS PASS'
