#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/fetch_cpu_references.py
python3 scripts/pack_vectors.py
python3 scripts/pack_arithmetic.py
mkdir -p work/full
verilator --cc --exe --build -j 4 -Wall --public-flat-rw --top-module mos_6502 --Mdir work/full \
    src/mos_6502.sv "$(pwd)/tb/full_test.cpp"
work/full/Vmos_6502
