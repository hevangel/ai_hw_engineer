#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
SRC="$HERE/src/mos_8520.sv $HERE/src/mos_8520_tod.sv $HERE/../mos_6526/src/mos_6526_timer.sv $HERE/../mos_6526/src/mos_6526_serial.sv $HERE/../mos_6526/src/mos_6526_irq.sv"
yosys -Q -T -p "read_verilog -sv $SRC; synth -top mos_8520; check -assert; stat" > "$HERE/work/8520-synth.log" 2>&1
grep -E "^ +[0-9]+ cells$" "$HERE/work/8520-synth.log" | tail -1
grep "Found and reported 0 problems" "$HERE/work/8520-synth.log" | tail -1
