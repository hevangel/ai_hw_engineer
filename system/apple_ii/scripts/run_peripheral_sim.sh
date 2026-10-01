#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
iverilog -g2012 -s tb_rev0_peripherals -o work/peripherals.vvp \
    ../../design/apple_ii_chips/src/analog/*.sv src/apple_ii_rev0_peripherals.sv tb/tb_rev0_peripherals.sv
vvp work/peripherals.vvp >work/peripherals.log 2>&1 || { cat work/peripherals.log; exit 1; }
cat work/peripherals.log
grep -q 'PASS revision-0' work/peripherals.log
