#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
python3 scripts/fetch_board_references.py
cc -std=c11 -shared -fPIC -O2 -I/usr/include/iverilog -Iwork/reference \
    board/cpu_reference.c work/reference/netlist_sim.c -o work/cpu_reference.vpi
iverilog -g2012 -s tb_rev0_boot -o work/boot.vvp \
    ../../design/apple_ii_chips/src/*.sv ../../design/apple_ii_chips/src/analog/*.sv \
    src/apple_ii_rev0_digital.sv src/apple_ii_rev0_peripherals.sv src/apple_ii_*output.sv src/apple_ii_rev0_reference.sv \
    board/reference_cpu_socket.sv board/a2_mos6502_reference.sv tb/tb_rev0_boot.sv
vvp -Mwork -mcpu_reference work/boot.vvp >work/boot.log 2>&1 || { cat work/boot.log; exit 1; }
cat work/boot.log
grep -q 'PASS historical Monitor' work/boot.log
python3 scripts/check_monitor_video.py
