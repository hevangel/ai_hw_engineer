#!/bin/sh
# Development gate for the native engine; not a substitute for run_all.sh/sign-off.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/native/obj"
if [ ! -s "$HERE/work/native/vectors.txt" ]; then
    echo 'Generate independent inputs with scripts/fetch_native_tests.py first.' >&2
    exit 2
fi
verilator --lint-only -Wall "$HERE/src/mos_6502_native.sv"
verilator --cc --exe --build --public-flat-rw -Wall -j 4 --top-module mos_6502_native \
    --Mdir "$HERE/work/native/obj" "$HERE/src/mos_6502_native.sv" "$HERE/tb/native_bus_test.cpp" \
    > "$HERE/work/native/build.log" 2>&1
"$HERE/work/native/obj/Vmos_6502_native" "$HERE/work/native/vectors.txt" \
    > "$HERE/work/native/run.log" 2>&1
grep 'NATIVE NMOS BUS PASS:' "$HERE/work/native/run.log"
