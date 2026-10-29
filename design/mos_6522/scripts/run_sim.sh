#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/sim"
verilator --binary --timing -Wall -Wno-TIMESCALEMOD -j 4 --top-module tb_top \
    --Mdir "$HERE/work/sim/obj" "$HERE/src/mos_6522.sv" "$HERE/tb/tb_top.sv" \
    > "$HERE/work/sim/build.log" 2>&1
"$HERE/work/sim/obj/Vtb_top" > "$HERE/work/sim/verilator.log" 2>&1
grep 'MOS 6522 PASS:' "$HERE/work/sim/verilator.log"
xezim --simulate --sv2017 --error-exit -s tb_top "$HERE/src/mos_6522.sv" \
    "$HERE/tb/tb_top.sv" +quick --max-time 10000000ns -l "$HERE/work/sim/xezim.log"
grep 'MOS 6522 PASS:' "$HERE/work/sim/xezim.log"
