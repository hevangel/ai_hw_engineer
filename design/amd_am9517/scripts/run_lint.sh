#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
echo "=== Am9517 strict RTL lint ==="
verilator --lint-only -Wall --top-module amd_am9517 "$HERE/src/amd_am9517.sv"
echo "=== Am9517 testbench lint ==="
# Simulation BFMs intentionally use blocking assignments and initialized variables;
# packed observations and integer task arguments also have unused bits.
verilator --lint-only -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL \
    --timing --top-module tb_top "$HERE/src/amd_am9517.sv" "$HERE/tb/tb_top.sv"
