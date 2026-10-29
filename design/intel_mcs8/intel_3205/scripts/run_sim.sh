#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SEED=${1:-1}
mkdir -p "$HERE/work/sim"
echo "=== Intel 3205 Verilator simulation ==="
verilator --binary -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL --timing -j 4 --top-module tb_top \
    --Mdir "$HERE/work/sim/obj" "$HERE/src/intel_3205.sv" "$HERE/tb/tb_top.sv" \
    > "$HERE/work/sim/build.log" 2>&1
"$HERE/work/sim/obj/Vtb_top" > "$HERE/work/sim/verilator.log" 2>&1
grep 'intel_3205 TEST PASSED' "$HERE/work/sim/verilator.log"
echo "=== Intel 3205 Xezim simulation ==="
xezim --simulate --sv2017 --error-exit -s tb_top \
    "$HERE/src/intel_3205.sv" "$HERE/tb/tb_top.sv" \
    --max-time 2000000000ns -l "$HERE/work/sim/xezim.log"
grep 'intel_3205 TEST PASSED' "$HERE/work/sim/xezim.log"
echo "Intel 3205 SIM PASSED"
