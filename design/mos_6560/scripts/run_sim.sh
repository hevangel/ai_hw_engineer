#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
verilator --lint-only -Wall "$HERE/src/mos_6560_regs.sv"
verilator --binary --timing -Wall -Wno-TIMESCALEMOD -j 4 --top-module tb_top \
    --Mdir "$HERE/work/sim" "$HERE/src/mos_6560_regs.sv" "$HERE/tb/tb_top.sv" \
    > "$HERE/work/build.log" 2>&1
"$HERE/work/sim/Vtb_top" > "$HERE/work/verilator.log" 2>&1
grep 'MOS 6560 REGS PASS:' "$HERE/work/verilator.log"
xezim --simulate --sv2017 --error-exit -s tb_top "$HERE/src/mos_6560_regs.sv" \
    "$HERE/tb/tb_top.sv" --max-time 1000000ns -l "$HERE/work/xezim.log"
grep 'MOS 6560 REGS PASS:' "$HERE/work/xezim.log"
