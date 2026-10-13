#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
echo "=== mos_6502 strict RTL lint ==="
verilator --lint-only -Wall --top-module mos_6502 "$HERE/src/mos_6502.sv"
echo "=== mos_6502 testbench lint ==="
# Simulation TB intentionally uses blocking assignments and initialized
# variables in its checker/watchdog processes; $readmemh arrays keep
# unused entries.
verilator --lint-only -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL \
    --timing --top-module tb_top "$HERE/src/mos_6502.sv" "$HERE/tb/tb_top.sv"
echo "lint clean"
