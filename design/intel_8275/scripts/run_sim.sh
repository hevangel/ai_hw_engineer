#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
mkdir -p "$HERE/work/sim" "$HERE/work/uvm"
verilator --binary --timing -j 4 -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL --top-module tb_top --Mdir "$HERE/work/sim/obj" "$HERE/src/intel_8275.sv" "$HERE/tb/tb_top.sv" > "$HERE/work/sim/build.log" 2>&1
for seed in "${1:-1}" 42 2026; do
  "$HERE/work/sim/obj/Vtb_top" +seed="$seed" +vectors="$HERE/references/graphics_vectors.hex" > "$HERE/work/sim/verilator_$seed.log" 2>&1
  grep '8275 PIN SUITE PASSED' "$HERE/work/sim/verilator_$seed.log"
  XEZIM_COV_DB="$HERE/work/sim/xezim_$seed.json" xezim --simulate --sv2017 --error-exit -s tb_top "$HERE/src/intel_8275.sv" "$HERE/tb/tb_top.sv" +seed="$seed" +vectors="$HERE/references/graphics_vectors.hex" > "$HERE/work/sim/xezim_$seed.log" 2>&1
  grep '8275 PIN SUITE PASSED' "$HERE/work/sim/xezim_$seed.log"
done
XEZIM_COV_DB="$HERE/work/uvm/coverage.json" xezim --simulate --sv2017 --error-exit -I "$ROOT/libs/uvm/1800.2-2017/src" -I "$HERE/tb" -D UVM_NO_DPI -D UVM_REPORT_DISABLE_FILE_LINE -s tb_uvm "$ROOT/libs/uvm/1800.2-2017/src/uvm_pkg.sv" "$HERE/tb/intel_8275_if.sv" "$HERE/tb/intel_8275_uvm_pkg.sv" "$HERE/src/intel_8275.sv" "$HERE/tb/tb_uvm.sv" +UVM_TESTNAME=intel_8275_test > "$HERE/work/uvm/run.log" 2>&1
grep '8275 UVM SCOREBOARD PASSED' "$HERE/work/uvm/run.log"
grep 'UVM_ERROR :    0' "$HERE/work/uvm/run.log"
grep 'UVM_FATAL :    0' "$HERE/work/uvm/run.log"
echo '8275 SIMULATION PASSED'
