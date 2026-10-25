#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/sim"
echo "=== MC6809 reyco2000 functional test (Verilator) ==="
verilator --binary --timing -Wall -Wno-BLKSEQ -Wno-PROCASSINIT \
    -Wno-UNUSEDSIGNAL -j 4 --top-module tb_top \
    --Mdir "$HERE/work/sim/obj" "$HERE/src/motorola_6809.sv" \
    "$HERE/tb/tb_top.sv" > "$HERE/work/sim/build.log" 2>&1
python3 "$HERE/scripts/s19_to_hex.py" 6809_functional_test.s19
(cd "$HERE" && ./work/sim/obj/Vtb_top > work/sim/verilator.log 2>&1)
grep 'MC6809 THIRD-PARTY TEST PASSED' "$HERE/work/sim/verilator.log"
echo "=== MC6809 reyco2000 interrupt test (Verilator) ==="
python3 "$HERE/scripts/s19_to_hex.py" 6809_interrupt_test.s19
(cd "$HERE" && ./work/sim/obj/Vtb_top > work/sim/verilator_int.log 2>&1)
grep 'MC6809 THIRD-PARTY TEST PASSED' "$HERE/work/sim/verilator_int.log"
echo "MC6809 simulation PASSED; logs: work/sim/verilator*.log"
