#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
python3 scripts/fetch_board_references.py
python3 scripts/prepare_cassette.py
cc -std=c11 -shared -fPIC -O2 -I/usr/include/iverilog -Iwork/reference \
    board/cpu_reference.c work/reference/netlist_sim.c -o work/cpu_reference.vpi
iverilog -g2012 -s tb_rev0_cassette -o work/cassette.vvp \
    ../../design/apple_ii_chips/src/*.sv ../../design/apple_ii_chips/src/analog/*.sv \
    src/apple_ii_rev0_digital.sv src/apple_ii_rev0_peripherals.sv src/apple_ii_cassette_output.sv src/apple_ii_rev0_reference.sv \
    board/reference_cpu_socket.sv board/a2_mos6502_reference.sv tb/tb_rev0_cassette.sv
for polarity in 1 -1; do
    vvp -Mwork -mcpu_reference work/cassette.vvp +POLARITY="$polarity" \
        >"work/cassette_$polarity.log" 2>&1 || { cat "work/cassette_$polarity.log"; exit 1; }
    cat "work/cassette_$polarity.log"
    grep -q 'PASS historical cassette byte routines' "work/cassette_$polarity.log"
    python3 scripts/check_cassette.py
    mv work/cassette_edges.csv "work/cassette_edges_$polarity.csv"
    mv work/cassette_input.csv "work/cassette_input_$polarity.csv"
done
