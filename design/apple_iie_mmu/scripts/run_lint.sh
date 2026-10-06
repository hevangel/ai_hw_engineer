#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
echo "=== Apple IIe MMU strict RTL lint ==="
verilator --lint-only -Wall --top-module apple_iie_mmu "$HERE/src/apple_iie_mmu.sv"
echo "=== Apple IIe MMU testbench lint ==="
# The self-checking bench uses blocking assignments in tasks and initialized
# variables; packed observation registers have unused bits by design.
verilator --lint-only -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL \
    --timing --top-module tb_top "$HERE/src/apple_iie_mmu.sv" "$HERE/tb/tb_top.sv"
