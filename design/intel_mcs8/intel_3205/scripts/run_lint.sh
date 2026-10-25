#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
echo "=== Intel 3205 verilator lint (RTL, no waivers) ==="
verilator --lint-only -Wall --top-module intel_3205 "$HERE/src/intel_3205.sv"
echo "=== Intel 3205 verilator lint (TB waivers) ==="
verilator --lint-only -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL \
    --top-module tb_top "$HERE/src/intel_3205.sv" "$HERE/tb/tb_top.sv"
echo "Intel 3205 LINT PASSED"
