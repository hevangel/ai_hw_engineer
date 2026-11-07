#!/bin/sh
# Strict lint of the S/360 M1 core and its testbench.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

echo "=== ibm_s360 RTL lint (Verilator -Wall) ==="
verilator --lint-only -Wall -I"$HERE/src" --top-module ibm_s360_cpu \
    "$HERE/src/ibm_s360_alu.sv" \
    "$HERE/src/ibm_s360_addr.sv" \
    "$HERE/src/ibm_s360_psw.sv" \
    "$HERE/src/ibm_s360_cpu.sv"

echo "=== ibm_s360 testbench lint ==="
# The testbench is a simulation-only checker: its memory model and scoreboard
# process use blocking assignments and initialized variables by design.
verilator --lint-only -Wall -I"$HERE/src" -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL \
    --timing --top-module tb_ibm_s360_cpu \
    "$HERE/src/ibm_s360_alu.sv" \
    "$HERE/src/ibm_s360_addr.sv" \
    "$HERE/src/ibm_s360_psw.sv" \
    "$HERE/src/ibm_s360_cpu.sv" \
    "$HERE/tb/tb_ibm_s360_cpu.sv"

echo "lint clean"
