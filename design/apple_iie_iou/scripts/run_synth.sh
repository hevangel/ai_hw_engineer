#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
echo "=== Apple IIe IOU generic synthesis ==="
yosys -Q -q -l "$HERE/work/synth/synth.log" -p "read_verilog -sv $HERE/src/apple_iie_iou.sv; hierarchy -check -top apple_iie_iou; synth -top apple_iie_iou; check -assert; stat; write_json $HERE/work/synth/apple_iie_iou.json; write_verilog -noattr $HERE/work/synth/apple_iie_iou.v"
echo "Apple IIe IOU SYNTHESIS PASSED; log: $HERE/work/synth/synth.log"
