#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
python3 scripts/fetch_board_references.py
python3 scripts/prepare_cassette.py
iverilog -g2012 -DAPPLE_II_CPU_MODULE=apple_ii_rev0_authored -s tb_rev0_cassette -o work/authored_cassette.vvp \
    ../../design/apple_ii_chips/src/*.sv ../../design/apple_ii_chips/src/analog/*.sv \
    ../../design/mos_6502/src/mos_6502.sv ../../design/mos_6502/src/a2_mos6502.sv \
    src/apple_ii_rev0_digital.sv src/apple_ii_rev0_peripherals.sv src/apple_ii_cassette_output.sv \
    src/apple_ii_rev0_authored.sv tb/tb_rev0_cassette.sv
for polarity in 1 -1; do
    vvp work/authored_cassette.vvp +POLARITY="$polarity" \
        >"work/authored_cassette_$polarity.log" 2>&1 || { cat "work/authored_cassette_$polarity.log"; exit 1; }
    cat "work/authored_cassette_$polarity.log"
    grep -q 'PASS historical cassette byte routines' "work/authored_cassette_$polarity.log"
    python3 scripts/check_cassette.py
    mv work/cassette_edges.csv "work/authored_cassette_edges_$polarity.csv"
    mv work/cassette_input.csv "work/authored_cassette_input_$polarity.csv"
done
