#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
echo "=== 8237A strict RTL lint ==="
verilator --lint-only -Wall --top-module intel_8237 "$HERE/src/intel_8237.sv"
echo "=== 8237A testbench lint ==="
# Simulation BFMs intentionally use blocking assignments and initialized variables;
# packed observations and integer task arguments also have unused bits.
verilator --lint-only -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL \
    --timing --top-module tb_top "$HERE/src/intel_8237.sv" "$HERE/tb/tb_top.sv"
