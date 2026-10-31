#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
python3 scripts/fetch_board_references.py
iverilog -g2012 -DAPPLE_II_CPU_MODULE=apple_ii_rev0_authored -s tb_rev0_boot -o work/authored_boot.vvp \
    ../../design/apple_ii_chips/src/*.sv ../../design/apple_ii_chips/src/analog/*.sv \
    ../../design/mos_6502_family/mos_6502/cycle/src/mos_6502_cycle.sv ../../design/mos_6502_family/mos_6502/cycle/src/a2_mos6502.sv \
    src/apple_ii_rev0_digital.sv src/apple_ii_rev0_peripherals.sv src/apple_ii_*output.sv \
    src/apple_ii_rev0_authored.sv tb/apple_ii_refresh_check.sv tb/tb_rev0_boot.sv
vvp work/authored_boot.vvp >work/authored_boot.log 2>&1 || { cat work/authored_boot.log; exit 1; }
cat work/authored_boot.log
grep -q 'PASS historical Monitor' work/authored_boot.log
python3 scripts/check_monitor_video.py
