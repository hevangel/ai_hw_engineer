#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
mkdir -p "$HERE/work/sim" "$HERE/work/link" "$HERE/work/dpll" "$HERE/work/uvm"
python3 "$HERE/scripts/generate_vectors.py"
verilator --binary --timing -j 4 -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL -I"$HERE/tb" --top-module tb_top --Mdir "$HERE/work/sim/obj" "$HERE"/src/*.sv "$HERE/tb/intel_8273_if.sv" "$HERE/tb/tb_top.sv" > "$HERE/work/sim/build.log" 2>&1
for seed in "${1:-1}" 42 2026; do
  "$HERE/work/sim/obj/Vtb_top" +vectors="$HERE/references/frames.txt" +seed="$seed" > "$HERE/work/sim/verilator_$seed.log" 2>&1
  grep '8273 SUITE PASSED' "$HERE/work/sim/verilator_$seed.log"
  XEZIM_COV_DB="$HERE/work/sim/xezim_$seed.json" xezim --simulate --sv2017 --error-exit -I "$HERE/tb" -s tb_top "$HERE"/src/*.sv "$HERE/tb/intel_8273_if.sv" "$HERE/tb/tb_top.sv" +vectors="$HERE/references/frames.txt" +seed="$seed" > "$HERE/work/sim/xezim_$seed.log" 2>&1
  grep '8273 SUITE PASSED' "$HERE/work/sim/xezim_$seed.log"
done
verilator --binary --timing -j 4 -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL -I"$HERE/tb" --top-module tb_long_frame --Mdir "$HERE/work/sim/long_obj" "$HERE"/src/*.sv "$HERE/tb/intel_8273_if.sv" "$HERE/tb/tb_long_frame.sv" > "$HERE/work/sim/long_build.log" 2>&1
"$HERE/work/sim/long_obj/Vtb_long_frame" +long_vectors="$HERE/work/sim/long_wire.hex" > "$HERE/work/sim/long_verilator.log" 2>&1
grep '8273 MAXIMUM FRAME PASSED' "$HERE/work/sim/long_verilator.log"
XEZIM_COV_DB="$HERE/work/sim/long_coverage.json" xezim --simulate --sv2017 --error-exit -I "$HERE/tb" -s tb_long_frame "$HERE"/src/*.sv "$HERE/tb/intel_8273_if.sv" "$HERE/tb/tb_long_frame.sv" +long_vectors="$HERE/work/sim/long_wire.hex" > "$HERE/work/sim/long_xezim.log" 2>&1
grep '8273 MAXIMUM FRAME PASSED' "$HERE/work/sim/long_xezim.log"
for top in tb_dma_link tb_dpll; do
  if [ "$top" = tb_dma_link ]; then
    sources="$ROOT/design/intel_8237/src/intel_8237.sv"
    dir=link
  else
    sources="$HERE/tb/intel_8273_if.sv"
    dir=dpll
  fi
  verilator --binary --timing -j 4 -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL --top-module "$top" --Mdir "$HERE/work/$dir/obj" "$HERE"/src/*.sv $sources "$HERE/tb/$top.sv" > "$HERE/work/$dir/build.log" 2>&1
  "$HERE/work/$dir/obj/V$top" +vectors="$HERE/references/frames.txt" > "$HERE/work/$dir/verilator.log" 2>&1
  grep '8273 .* PASSED' "$HERE/work/$dir/verilator.log"
  XEZIM_COV_DB="$HERE/work/$dir/coverage.json" xezim --simulate --sv2017 --error-exit -s "$top" "$HERE"/src/*.sv $sources "$HERE/tb/$top.sv" +vectors="$HERE/references/frames.txt" > "$HERE/work/$dir/xezim.log" 2>&1
  grep '8273 .* PASSED' "$HERE/work/$dir/xezim.log"
done
XEZIM_COV_DB="$HERE/work/uvm/coverage.json" xezim --simulate --sv2017 --error-exit -I "$ROOT/libs/uvm/1800.2-2017/src" -I "$HERE/tb" -D UVM_NO_DPI -D UVM_REPORT_DISABLE_FILE_LINE -s tb_uvm "$ROOT/libs/uvm/1800.2-2017/src/uvm_pkg.sv" "$HERE/tb/intel_8273_if.sv" "$HERE/tb/intel_8273_uvm_pkg.sv" "$HERE"/src/*.sv "$HERE/tb/tb_uvm.sv" +vectors="$HERE/references/frames.txt" +UVM_TESTNAME=intel_8273_test > "$HERE/work/uvm/run.log" 2>&1
grep '8273 UVM SCOREBOARD PASSED' "$HERE/work/uvm/run.log"
grep 'UVM_ERROR :    0' "$HERE/work/uvm/run.log"
grep 'UVM_FATAL :    0' "$HERE/work/uvm/run.log"
echo '8273 SIMULATION PASSED'
