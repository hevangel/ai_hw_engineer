#!/bin/sh
set -e
cd "$(dirname "$0")/.."
echo "Running 6502 initial instruction regression"
mkdir -p work/sim
verilator --binary --timing -Wall --top-module tb_top --Mdir work/sim src/mos_6502.sv tb/tb_top.sv
./work/sim/Vtb_top
mkdir -p work/control
verilator --cc --exe --build -Wall --top-module mos_6502 --Mdir work/control \
    src/mos_6502.sv "$(pwd)/tb/control_test.cpp"
./work/control/Vmos_6502
