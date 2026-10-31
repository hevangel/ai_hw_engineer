#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/chip"
verilator --lint-only -Wall --top-module mos_6526 "$HERE"/src/*.sv
verilator --binary --timing -Wall -Wno-TIMESCALEMOD -j 4 --top-module tb_top \
    --Mdir "$HERE/work/chip" "$HERE"/src/*.sv "$HERE/tb/tb_top.sv" > "$HERE/work/chip-build.log" 2>&1
"$HERE/work/chip/Vtb_top" > "$HERE/work/chip-verilator.log" 2>&1
grep 'MOS 6526 INTEGRATION PASS:' "$HERE/work/chip-verilator.log"
xezim --simulate --sv2017 --error-exit -s tb_top "$HERE"/src/*.sv \
    "$HERE/tb/tb_top.sv" --max-time 2000000ns -l "$HERE/work/chip-xezim.log"
grep 'MOS 6526 INTEGRATION PASS:' "$HERE/work/chip-xezim.log"
