#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
yosys -Q -T -p "read_verilog -sv $HERE/src/mos_6560_regs.sv; synth -top mos_6560_regs; check -assert; stat" \
    > "$HERE/work/synth.log" 2>&1
tail -n 24 "$HERE/work/synth.log"
