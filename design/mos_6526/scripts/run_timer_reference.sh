#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REF="$HERE/work/reference"
OUT="$HERE/work/timer-reference"
mkdir -p "$OUT"
python3 "$HERE/scripts/fetch_timer_reference.py"
gcc -O2 -I"$REF" -I"$HERE/tb/vice_stubs" -c "$REF/ciatimer.c" -o "$OUT/vice.o"
gcc -O2 -I"$REF" -I"$HERE/tb/vice_stubs" -c "$HERE/tb/vice_timer_adapter.c" -o "$OUT/adapter.o"
verilator --lint-only -Wall "$HERE/src/mos_6526_timer.sv"
verilator --cc --exe --build -Wall -j 4 --top-module mos_6526_timer --Mdir "$OUT" \
    "$HERE/src/mos_6526_timer.sv" "$HERE/tb/timer_reference_test.cpp" \
    -LDFLAGS "$OUT/vice.o $OUT/adapter.o" > "$HERE/work/timer-build.log" 2>&1
"$OUT/Vmos_6526_timer" > "$HERE/work/timer-reference.log" 2>&1
cat "$HERE/work/timer-reference.log"
