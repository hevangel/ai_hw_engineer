#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
python3 scripts/fetch_board_references.py
iverilog -g2012 -DAPPLE_II_CPU_MODULE=apple_ii_rev0_authored -s tb_rev0_full_write -o work/full_write.vvp \
    ../../design/apple_ii_chips/src/*.sv ../../design/apple_ii_chips/src/analog/*.sv \
    ../../design/mos_6502/src/mos_6502.sv ../../design/mos_6502/src/a2_mos6502.sv \
    src/apple_ii_rev0_digital.sv src/apple_ii_rev0_peripherals.sv src/apple_ii_*output.sv \
    src/apple_ii_rev0_authored.sv tb/tb_rev0_full_write.sv
vvp work/full_write.vvp >work/full_write.log 2>&1 || { cat work/full_write.log; exit 1; }
cat work/full_write.log
grep -q 'PASS full physical original' work/full_write.log
python3 scripts/check_full_write_board.py
