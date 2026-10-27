#!/bin/sh
# Generic Yosys synthesis and structural check of the SONY S-DSP RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv -I"$HERE/src" "$HERE/src/sony_s_dsp.sv"; synth -top sony_s_dsp -flatten; check -assert; stat" \
    > "$HERE/work/synth/yosys.log" 2>&1 || { tail -30 "$HERE/work/synth/yosys.log"; exit 1; }
grep -E "Number of cells" "$HERE/work/synth/yosys.log" | tail -1
echo 'SONY S-DSP SYNTHESIS PASS'
