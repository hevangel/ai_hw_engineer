#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROFILE=${1:-1}
case "$PROFILE" in 0|1) ;; *) echo 'Expected Timer B loss profile 0 or 1' >&2; exit 2;; esac
BUILD=software
if [ "$PROFILE" = 0 ]; then BUILD=software_no_loss; fi
mkdir -p "$HERE/work/$BUILD"
python3 "$HERE/scripts/fetch_software.py"
verilator --cc --exe --build -Wall -j 4 --top-module cia_software_top \
    -GTIMER_B_READ_LOSS="$PROFILE" --Mdir "$HERE/work/$BUILD" "$HERE"/src/*.sv \
    "$HERE/../mos_6502_family/mos_6502/src/mos_6502_native.sv" "$HERE/tb/cia_software_top.sv" \
    "$HERE/tb/cia_software_test.cpp" > "$HERE/work/$BUILD-build.log" 2>&1
"$HERE/work/$BUILD/Vcia_software_top" "$HERE/work/lorenz/cia1pb6.prg" \
    "$HERE/work/lorenz/cia1pb7.prg" > "$HERE/work/$BUILD.log" 2>&1
"$HERE/work/$BUILD/Vcia_software_top" --kernal "$HERE/work/lorenz/kernal.901227-03.bin" \
    "$HERE/work/lorenz/cia1pb6.prg" "$HERE/work/lorenz/cia1pb7.prg" \
    "$HERE/work/lorenz/cia1ta.prg" "$HERE/work/lorenz/cia1tb.prg" \
    "$HERE/work/lorenz/cia1tab.prg" "$HERE/work/lorenz/cia1tb123.prg" \
    "$HERE/work/lorenz/cia2pb6.prg" "$HERE/work/lorenz/cia2pb7.prg" \
    "$HERE/work/lorenz/cia2ta.prg" "$HERE/work/lorenz/cia2tb.prg" \
    "$HERE/work/lorenz/cia2tb123.prg" >> "$HERE/work/$BUILD.log" 2>&1
grep 'MOS 6526 LORENZ PASS:' "$HERE/work/$BUILD.log"
