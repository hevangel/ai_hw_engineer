#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Refresh instrument check (review item P2).
#
# The Monitor boot gate instantiates tb/apple_ii_refresh_check.sv, asserts that
# all 128 rows are refreshed and prints the worst same-row gap. This script
# proves the instrument itself is not vacuous: with an idle CPU socket the video
# scan is the only refresh source, so the same checker must report gaps beyond
# the 4116's 2 ms requirement. A checker that reported zero either way would
# pass the boot gate for the wrong reason.
mkdir -p work
iverilog -g2012 -s tb_refresh_video_only -o work/refresh_video_only.vvp \
    ../../design/apple_ii_chips/src/*.sv src/apple_ii_rev0_digital.sv \
    tb/apple_ii_refresh_check.sv tb/tb_refresh_video_only.sv
vvp work/refresh_video_only.vvp | tee work/refresh_video_only.log
grep -q 'VIDEO-ONLY rows=128' work/refresh_video_only.log
echo 'PASS refresh checker reports the video-only margin (negative control)'
