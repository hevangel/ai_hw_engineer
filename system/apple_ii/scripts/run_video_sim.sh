#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
python3 scripts/fetch_board_references.py
iverilog -g2012 -s tb_rev0_video -o work/video.vvp \
    ../../design/apple_ii_chips/src/*.sv src/apple_ii_rev0_digital.sv tb/tb_rev0_video.sv
vvp work/video.vvp >work/video.log 2>&1 || { cat work/video.log; exit 1; }
cat work/video.log
grep -q 'PASS digital video capture timing' work/video.log
python3 scripts/check_video.py
