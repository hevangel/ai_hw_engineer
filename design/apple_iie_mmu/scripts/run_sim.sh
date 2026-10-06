#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SEED=${1:-1}
mkdir -p "$HERE/work/sim"
echo "=== Apple IIe MMU Verilator simulation seed=$SEED ==="
verilator --binary -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL --timing -j 4 --top-module tb_top \
    --Mdir "$HERE/work/sim/obj" "$HERE/src/apple_iie_mmu.sv" "$HERE/tb/tb_top.sv" \
    > "$HERE/work/sim/build.log" 2>&1
"$HERE/work/sim/obj/Vtb_top" "+seed=$SEED" > "$HERE/work/sim/verilator.log" 2>&1
grep 'Apple IIe MMU TEST PASSED' "$HERE/work/sim/verilator.log"
echo "=== Apple IIe MMU Xezim simulation seed=$SEED ==="
XEZIM_COV_DB="$HERE/work/sim/xezim_cov.json" \
xezim --simulate --sv2017 --error-exit -s tb_top \
    "$HERE/src/apple_iie_mmu.sv" "$HERE/tb/tb_top.sv" "+seed=$SEED" \
    --max-time 10000000ns -l "$HERE/work/sim/xezim.log"
grep 'Apple IIe MMU TEST PASSED' "$HERE/work/sim/xezim.log"
