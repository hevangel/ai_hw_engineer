#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/sim"
echo "=== motorola_6800 vector regeneration (independent Python oracle) ==="
python3 "$HERE/scripts/make_isa_vectors.py"
echo "=== MC6800 Verilator full-ISA simulation ==="
# TB waiver rationale as in mos_6502: the checker/watchdog processes use
# blocking assignments and initialized variables by design.
verilator --binary --timing -Wall -Wno-BLKSEQ -Wno-PROCASSINIT \
    -Wno-UNUSEDSIGNAL -j 4 --top-module tb_top \
    --Mdir "$HERE/work/sim/obj" "$HERE/src/motorola_6800.sv" \
    "$HERE/tb/tb_top.sv" > "$HERE/work/sim/build.log" 2>&1
(cd "$HERE" && ./work/sim/obj/Vtb_top > work/sim/verilator.log 2>&1)
grep 'MC6800 FULL ISA TEST PASSED' "$HERE/work/sim/verilator.log"
echo "MC6800 simulation PASSED; log: $HERE/work/sim/verilator.log"
