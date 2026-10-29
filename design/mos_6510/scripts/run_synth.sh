#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"
yosys -Q -p "read_verilog -sv $HERE/../mos_6502_family/mos_6502/src/mos_6502_native.sv $HERE/src/mos_6510_port.sv $HERE/src/mos_6510.sv; synth -top mos_6510 -flatten; check; stat; write_json $HERE/work/synth/mos_6510.json" \
    > "$HERE/work/synth/yosys.log" 2>&1
echo 'MOS 6510 SYNTHESIS PASS'
