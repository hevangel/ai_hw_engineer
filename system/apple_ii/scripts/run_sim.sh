#!/bin/sh
set -e
cd "$(dirname "$0")/.."
mkdir -p work/sim
echo "Running Apple II memory/keyboard regression"
verilator --binary --timing -Wall --top-module tb_top --Mdir work/sim src/apple_ii_memory.sv tb/tb_top.sv
./work/sim/Vtb_top
mkdir -p work/echo
verilator --binary --timing -Wall --top-module tb_echo --Mdir work/echo \
    src/apple_ii.sv src/apple_ii_memory.sv ../../design/mos_6502/src/mos_6502.sv tb/tb_echo.sv
./work/echo/Vtb_echo
