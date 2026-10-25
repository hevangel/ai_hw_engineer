#!/bin/sh
# Complete Space Invaders system verification: lint, board testbench,
# original-ROM regression with independent-oracle comparison, backend API
# test and synthesis check.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work"

echo "== Original ROM images"
python3 "$SYSTEM/scripts/fetch_roms.py"

echo "== Lint (verilator --lint-only -Wall)"
verilator --lint-only -Wall --top-module space_invaders \
    "$ROOT/design/intel_8080/src/intel_8080.sv" \
    "$ROOT/design/intel_8080/src/intel_8080_alu.sv" \
    "$SYSTEM/src/space_invaders.sv" \
    "$SYSTEM/src/si_memory.sv" \
    "$SYSTEM/src/si_shift.sv"

echo "== Board testbench (boot, interrupts, shift register, coin)"
verilator --binary --timing -Wall -Wno-UNUSEDSIGNAL -Wno-PROCASSINIT \
    --top-module tb_top --Mdir "$SYSTEM/work/obj_test" -j 4 \
    "$ROOT/design/intel_8080/src/intel_8080.sv" \
    "$ROOT/design/intel_8080/src/intel_8080_alu.sv" \
    "$SYSTEM/src/space_invaders.sv" "$SYSTEM/src/si_memory.sv" \
    "$SYSTEM/src/si_shift.sv" "$SYSTEM/tb/tb_top.sv" \
    > "$SYSTEM/work/test_build.log" 2>&1
"$SYSTEM/work/obj_test/Vtb_top" "+rom=$SYSTEM/work/si_rom.hex"

echo "== Original ROM: oracle checkpoint, attract and play"
sh "$SYSTEM/scripts/build.sh"
python3 "$SYSTEM/scripts/test_software.py"

echo "== Backend HTTP API"
python3 "$SYSTEM/scripts/test_backend.py"

echo "== Synthesis check"
sh "$SYSTEM/scripts/run_synth.sh"

echo "PASS: Space Invaders complete system verification"
