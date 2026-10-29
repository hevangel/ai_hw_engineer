#!/bin/sh
# Complete SNES system verification: lint (NTSC and PAL), Peter Lemon
# test-ROM regression against the author's reference screens, backend API
# test and synthesis check.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
. "$SYSTEM/scripts/sources.sh"
mkdir -p "$SYSTEM/work"

echo "== Test ROMs and IPL image"
python3 "$SYSTEM/scripts/fetch_roms.py"
python3 "$ROOT/design/sony_s_smp/scripts/fetch_ipl.py"

echo "== Lint (verilator --lint-only -Wall, NTSC and PAL)"
for region in 0 1; do
    verilator --lint-only -Wall $SNES_INC --top-module snes -GPAL=1\'b$region $SNES_SRC
done

echo "== Software: Peter Lemon test ROMs"
sh "$SYSTEM/scripts/build.sh"
python3 "$SYSTEM/scripts/test_software.py"

echo "== Backend HTTP API"
python3 "$SYSTEM/scripts/test_backend.py"

echo "== Synthesis check"
sh "$SYSTEM/scripts/run_synth.sh"

echo "PASS: SNES complete system verification"
