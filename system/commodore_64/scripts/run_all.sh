#!/bin/sh
# Complete Commodore 64 system verification: firmware fetch, lint, the
# independent VICE x64sc oracle comparison (PAL cycle-exact, NTSC
# functional), the original-ROM software regression on both boards, the
# backend API test and the synthesis check.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$SYSTEM/work"

echo "== Original ROM images"
python3 "$SYSTEM/scripts/fetch_firmware.py"

echo "== Lint (verilator --lint-only -Wall)"
sh "$SYSTEM/scripts/run_lint.sh"

echo "== Build (PAL and NTSC)"
C64_VARIANT=0 sh "$SYSTEM/scripts/build.sh"
C64_VARIANT=1 sh "$SYSTEM/scripts/build.sh"

echo "== Independent oracle: VICE x64sc"
python3 "$SYSTEM/scripts/test_oracle.py"
python3 "$SYSTEM/scripts/test_oracle.py" --ntsc

echo "== Original ROM regression"
python3 "$SYSTEM/scripts/test_software.py"
python3 "$SYSTEM/scripts/test_software.py" --ntsc

echo "== Backend HTTP API"
python3 "$SYSTEM/scripts/test_backend.py"

echo "== Synthesis check"
sh "$SYSTEM/scripts/run_synth.sh"

echo "PASS: Commodore 64 complete system verification"
