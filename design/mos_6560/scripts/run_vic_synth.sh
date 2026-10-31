#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
SRC="$HERE/src/mos_6560.sv $HERE/src/mos_6560_regs.sv $HERE/src/mos_6560_raster.sv $HERE/src/mos_6560_video.sv $HERE/src/mos_6560_lightpen.sv $HERE/src/mos_6560_audio.sv"
for profile in 1 0; do
    yosys -Q -T -p "read_verilog -sv $SRC; chparam -set PAL $profile mos_6560; synth -top mos_6560; check -assert; stat" \
        > "$HERE/work/vic-synth-$profile.log" 2>&1
    echo "== PAL=$profile"
    grep -E "^ +[0-9]+ cells$" "$HERE/work/vic-synth-$profile.log" | tail -1
    grep "Found and reported 0 problems" "$HERE/work/vic-synth-$profile.log" | tail -1
done
