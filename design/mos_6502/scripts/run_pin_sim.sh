#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 ../../system/apple_ii/scripts/fetch_board_references.py
mkdir -p work/pins
reference="$(pwd)/../../system/apple_ii/work/reference"
cc -O2 -I"$reference" -c "$reference/netlist_sim.c" -o work/pins/netlist_sim.o
cc -O2 -I"$reference" -c tb/pin_oracle.c -o work/pins/pin_oracle.o
verilator --cc --exe --build -j 4 -Wall --top-module mos_6502 --Mdir work/pins \
    -LDFLAGS "$(pwd)/work/pins/netlist_sim.o $(pwd)/work/pins/pin_oracle.o" \
    src/mos_6502.sv "$(pwd)/tb/pin_test.cpp"
work/pins/Vmos_6502
