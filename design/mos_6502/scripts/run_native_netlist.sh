#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REF="$HERE/work/native/netlist"
OUT="$HERE/work/native/netlist-build"
mkdir -p "$OUT"
python3 "$HERE/scripts/fetch_native_netlist.py"
gcc -O2 -I"$REF" -c "$HERE/tb/native_netlist_adapter.c" -o "$OUT/adapter.o"
gcc -O2 -I"$REF" -c "$REF/netlist_sim.c" -o "$OUT/netlist.o"
verilator --cc --exe --build --public-flat-rw -Wall -j 4 --top-module mos_6502_native \
    --Mdir "$OUT" "$HERE/src/mos_6502_native.sv" "$HERE/tb/native_netlist_test.cpp" \
    -LDFLAGS "$OUT/adapter.o $OUT/netlist.o" > "$HERE/work/native/netlist-build.log" 2>&1
"$OUT/Vmos_6502_native" > "$HERE/work/native/netlist.log" 2>&1
cat "$HERE/work/native/netlist.log"
