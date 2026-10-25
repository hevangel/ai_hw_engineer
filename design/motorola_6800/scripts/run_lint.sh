#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/lint"
echo '=== MC6800 RTL Verilator -Wall lint ==='
verilator --lint-only -Wall --top-module motorola_6800 \
    "$HERE/src/motorola_6800.sv" > "$HERE/work/lint/rtl.log" 2>&1
echo '=== MC6800 testbench lint (TB checkers use blocking assigns) ==='
verilator --lint-only -Wall -Wno-BLKSEQ -Wno-PROCASSINIT \
    -Wno-UNUSEDSIGNAL --top-module tb_top \
    "$HERE/src/motorola_6800.sv" "$HERE/tb/tb_top.sv" \
    > "$HERE/work/lint/tb.log" 2>&1
echo 'MC6800 lint PASSED; logs: work/lint/'
