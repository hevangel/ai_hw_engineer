#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
python3 scripts/fetch_board_references.py
iverilog -g2012 -DAPPLE_II_CPU_MODULE=apple_ii_rev0_authored -s tb_rev0_basic -o work/basic.vvp \
    ../../design/apple_ii_chips/src/*.sv ../../design/apple_ii_chips/src/analog/*.sv \
    ../../design/mos_6502_cycle/src/mos_6502_cycle.sv ../../design/mos_6502_cycle/src/a2_mos6502.sv \
    src/apple_ii_rev0_digital.sv src/apple_ii_rev0_peripherals.sv src/apple_ii_*output.sv \
    src/apple_ii_rev0_authored.sv tb/tb_rev0_basic.sv
vvp work/basic.vvp >work/basic.log 2>&1 || { cat work/basic.log; exit 1; }
cat work/basic.log
grep -q 'PASS original Integer BASIC' work/basic.log
python3 scripts/check_basic_output.py
