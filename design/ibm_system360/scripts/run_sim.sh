#!/bin/sh
# Build and run the self-checking M1 core testbench with Verilator.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/sim"

echo "=== ibm_s360 M1 core simulation (Verilator) ==="
verilator --binary --timing -Wall -I"$HERE/src" -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL \
    -j 4 --top-module tb_ibm_s360_cpu \
    --Mdir "$HERE/work/sim/obj" \
    "$HERE/src/ibm_s360_alu.sv" \
    "$HERE/src/ibm_s360_addr.sv" \
    "$HERE/src/ibm_s360_psw.sv" \
    "$HERE/src/ibm_s360_cpu.sv" \
    "$HERE/tb/tb_ibm_s360_cpu.sv" \
    > "$HERE/work/sim/build.log" 2>&1

(cd "$HERE" && ./work/sim/obj/Vtb_ibm_s360_cpu > work/sim/verilator.log 2>&1)
cat "$HERE/work/sim/verilator.log"
grep -q 'IBM S360 M1 CORE TESTS PASSED' "$HERE/work/sim/verilator.log"
echo "=== ibm_s360 M1 core simulation passed ==="
