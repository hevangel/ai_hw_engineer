#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
mkdir -p "$HERE/work/sim" "$HERE/work/uvm" "$HERE/work/codec"
verilator --binary --timing -j 4 -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL -I"$HERE/tb" --top-module tb_top --Mdir "$HERE/work/sim/obj" "$HERE/src/intel_8272.sv" "$HERE/tb/intel_8272_if.sv" "$HERE/tb/tb_top.sv" > "$HERE/work/sim/build.log" 2>&1
for seed in "${1:-1}" 42 2026; do
  "$HERE/work/sim/obj/Vtb_top" +seed="$seed" > "$HERE/work/sim/verilator_$seed.log" 2>&1
  grep '8272 SUITE PASSED' "$HERE/work/sim/verilator_$seed.log"
  XEZIM_COV_DB="$HERE/work/sim/xezim_$seed.json" xezim --simulate --sv2017 --error-exit -I "$HERE/tb" -s tb_top "$HERE/src/intel_8272.sv" "$HERE/tb/intel_8272_if.sv" "$HERE/tb/tb_top.sv" +seed="$seed" > "$HERE/work/sim/xezim_$seed.log" 2>&1
  grep '8272 SUITE PASSED' "$HERE/work/sim/xezim_$seed.log"
done
verilator --binary --timing -j 4 -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL --top-module tb_codec --Mdir "$HERE/work/codec/obj" "$HERE/src/intel_8272_codec.sv" "$HERE/src/intel_8272_crc.sv" "$HERE/tb/tb_codec.sv" > "$HERE/work/codec/build.log" 2>&1
"$HERE/work/codec/obj/Vtb_codec" +vectors="$HERE/references/codec_vectors.hex" > "$HERE/work/codec/verilator.log" 2>&1
grep '8272 CODEC PASSED' "$HERE/work/codec/verilator.log"
XEZIM_COV_DB="$HERE/work/codec/coverage.json" xezim --simulate --sv2017 --error-exit -s tb_codec "$HERE/src/intel_8272_codec.sv" "$HERE/src/intel_8272_crc.sv" "$HERE/tb/tb_codec.sv" +vectors="$HERE/references/codec_vectors.hex" > "$HERE/work/codec/xezim.log" 2>&1
grep '8272 CODEC PASSED' "$HERE/work/codec/xezim.log"
XEZIM_COV_DB="$HERE/work/uvm/coverage.json" xezim --simulate --sv2017 --error-exit -I "$ROOT/libs/uvm/1800.2-2017/src" -I "$HERE/tb" -D UVM_NO_DPI -D UVM_REPORT_DISABLE_FILE_LINE -s tb_uvm "$ROOT/libs/uvm/1800.2-2017/src/uvm_pkg.sv" "$HERE/tb/intel_8272_if.sv" "$HERE/tb/intel_8272_uvm_pkg.sv" "$HERE/src/intel_8272.sv" "$HERE/tb/tb_uvm.sv" +UVM_TESTNAME=intel_8272_test > "$HERE/work/uvm/run.log" 2>&1
grep '8272 UVM SCOREBOARD PASSED' "$HERE/work/uvm/run.log"
grep 'UVM_ERROR :    0' "$HERE/work/uvm/run.log"
grep 'UVM_FATAL :    0' "$HERE/work/uvm/run.log"
echo '8272 SIMULATION PASSED'
