#!/bin/sh
# Complete Altair 8800 system verification: lint, board testbench, original
# 4K BASIC 3.2 boot via panel+tape, backend API test and synthesis check.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work"

echo "== Lint (verilator --lint-only -Wall)"
verilator --lint-only -Wall --top-module altair_8800 \
    "$ROOT/design/intel_8080/src/intel_8080.sv" \
    "$ROOT/design/intel_8080/src/intel_8080_alu.sv" \
    "$SYSTEM/src/altair_8800.sv" \
    "$SYSTEM/src/altair_ram.sv"

echo "== Board testbench (panel, SIO, sense switches)"
# UNUSEDSIGNAL/PROCASSINIT are testbench-observation and clock-init idioms.
verilator --binary --timing -Wall -Wno-UNUSEDSIGNAL -Wno-PROCASSINIT --top-module tb_top \
    --Mdir "$SYSTEM/work/obj_test" \
    "$ROOT/design/intel_8080/src/intel_8080.sv" \
    "$ROOT/design/intel_8080/src/intel_8080_alu.sv" \
    "$SYSTEM/src/altair_8800.sv" "$SYSTEM/src/altair_ram.sv" \
    "$SYSTEM/tb/tb_top.sv" \
    > "$SYSTEM/work/test_build.log" 2>&1
"$SYSTEM/work/obj_test/Vtb_top"

echo "== Original 4K BASIC 3.2 through the front panel and 88-SIO"
python3 "$SYSTEM/scripts/fetch_firmware.py"
sh "$SYSTEM/scripts/build.sh"
python3 "$SYSTEM/scripts/test_software.py"

echo "== Backend HTTP API"
python3 "$SYSTEM/scripts/test_backend.py"

echo "== Synthesis check"
sh "$SYSTEM/scripts/run_synth.sh"

echo "PASS: Altair 8800 complete system verification"
