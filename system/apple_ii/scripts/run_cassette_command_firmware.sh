#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/fetch_board_references.py
mkdir -p work/cassette_command
verilator --cc --exe --build -j 4 -Wall --top-module mos_6502 --Mdir work/cassette_command \
    ../../design/mos_6502/src/mos_6502.sv "$(pwd)/tb/cassette_command_test.cpp"
work/cassette_command/Vmos_6502
