#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
SEED=${1:-1}
mkdir -p "$HERE/work/sim"
echo "=== Am9517 Verilator simulation seed=$SEED ==="
verilator --binary -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL --timing -j 4 --top-module tb_top \
    --Mdir "$HERE/work/sim/obj" "$HERE/src/amd_am9517.sv" "$HERE/tb/tb_top.sv" \
    > "$HERE/work/sim/build.log" 2>&1
"$HERE/work/sim/obj/Vtb_top" "+seed=$SEED" > "$HERE/work/sim/verilator.log" 2>&1
grep 'Am9517 TEST PASSED' "$HERE/work/sim/verilator.log"
echo "=== Am9517 Xezim simulation seed=$SEED ==="
XEZIM_COV_DB="$HERE/work/sim/xezim_cov.json" \
xezim --simulate --sv2017 --error-exit -s tb_top \
    "$HERE/src/amd_am9517.sv" "$HERE/tb/tb_top.sv" "+seed=$SEED" \
    --max-time 5000000ns -l "$HERE/work/sim/xezim.log"
grep 'Am9517 TEST PASSED' "$HERE/work/sim/xezim.log"
echo "=== Am9517 UVM regression ==="
XEZIM_COV_DB="$HERE/work/sim/uvm_cov.json" \
xezim --simulate --sv2017 --error-exit -s tb_uvm \
    -I "$ROOT/libs/uvm/1800.2-2017/src" -I "$HERE/tb" \
    -D UVM_NO_DPI -D UVM_REPORT_DISABLE_FILE_LINE \
    "$ROOT/libs/uvm/1800.2-2017/src/uvm_pkg.sv" \
    "$HERE/src/amd_am9517.sv" "$HERE/tb/amd_am9517_if.sv" \
    "$HERE/tb/amd_am9517_uvm_pkg.sv" "$HERE/tb/tb_uvm.sv" \
    +UVM_TESTNAME=amd_am9517_test "+seed=$SEED" \
    --max-time 200000ns -l "$HERE/work/sim/uvm.log"
grep 'Am9517 UVM PASSED' "$HERE/work/sim/uvm.log"
if grep -Eq 'UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]' "$HERE/work/sim/uvm.log"; then exit 1; fi
