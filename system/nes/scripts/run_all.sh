#!/bin/sh
# Complete NES system verification: lint (NTSC and PAL), board testbench,
# nestest trace and blargg test-ROM regressions, backend API test and
# synthesis check.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
. "$SYSTEM/scripts/sources.sh"
mkdir -p "$SYSTEM/work"

echo "== Test ROMs"
python3 "$SYSTEM/scripts/fetch_roms.py"

echo "== Lint (verilator --lint-only -Wall, NTSC and PAL)"
for region in 0 1; do
    verilator --lint-only -Wall --top-module nes -GREGION=1\'b$region $NES_SRC
done

echo "== Board testbench (clock ratios, frame period, nestest automation)"
python3 "$SYSTEM/scripts/prepare_rom.py" "$SYSTEM/work/roms/other/nestest.nes" \
    "$SYSTEM/work/images/tb_nestest" --entry C000 > /dev/null
verilator --binary --timing -Wall -Wno-UNUSEDSIGNAL \
    --top-module tb_top --Mdir "$SYSTEM/work/obj_test" -j 4 \
    $NES_SRC "$SYSTEM/tb/tb_top.sv" > "$SYSTEM/work/test_build.log" 2>&1
"$SYSTEM/work/obj_test/Vtb_top" "+prg=$SYSTEM/work/images/tb_nestest.prg.hex" \
    "+chr=$SYSTEM/work/images/tb_nestest.chr.hex"

echo "== Software: nestest.log trace and blargg test ROMs"
sh "$SYSTEM/scripts/build.sh"
python3 "$SYSTEM/scripts/test_software.py"

echo "== Backend HTTP API"
python3 "$SYSTEM/scripts/test_backend.py"

echo "== Synthesis check"
sh "$SYSTEM/scripts/run_synth.sh"

echo "PASS: NES complete system verification"
