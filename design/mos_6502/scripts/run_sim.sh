#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SEED=${1:-1}
mkdir -p "$HERE/work/sim"
echo "=== mos_6502 vector regeneration (py65 oracle + canonical SBC-decimal) ==="
python3 "$HERE/scripts/make_isa_vectors.py"
echo "=== Apple 6502 Verilator simulation seed=$SEED ==="
# TB lint waivers as in run_lint.sh: the TB's checker/watchdog processes use
# blocking assignments and initialized variables by design.
verilator --binary --timing -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL -j 4 --top-module tb_top \
    --Mdir "$HERE/work/sim/obj" "$HERE/src/mos_6502.sv" "$HERE/tb/tb_top.sv" \
    > "$HERE/work/sim/build.log" 2>&1
(cd "$HERE" && ./work/sim/obj/Vtb_top "+seed=$SEED" > work/sim/verilator.log 2>&1)
grep 'Apple 6502 FULL ISA TEST PASSED' "$HERE/work/sim/verilator.log"
echo "=== Apple 6502 Verilator Klaus functional test ==="
(cd "$HERE" && ./work/sim/obj/Vtb_top +klaus > work/sim/klaus.log 2>&1)
grep 'Apple 6502 KLAUS TEST PASSED' "$HERE/work/sim/klaus.log"
echo "=== Apple 6502 control unit test ==="
mkdir -p "$HERE/work/control"
verilator --cc --exe --build -Wall --top-module mos_6502 --Mdir "$HERE/work/control" \
    "$HERE/src/mos_6502.sv" "$HERE/tb/control_test.cpp" \
    > "$HERE/work/control/build.log" 2>&1
(cd "$HERE" && ./work/control/Vmos_6502 > work/sim/control.log 2>&1)
echo "control test passed"
echo "=== Apple 6502 Xezim simulation seed=$SEED ==="
(cd "$HERE" && xezim --simulate --sv2017 --error-exit -s tb_top \
    "$HERE/src/mos_6502.sv" "$HERE/tb/tb_top.sv" "+seed=$SEED" \
    --max-time 2000000000ns -l "$HERE/work/sim/xezim.log")
grep 'Apple 6502 FULL ISA TEST PASSED' "$HERE/work/sim/xezim.log"
