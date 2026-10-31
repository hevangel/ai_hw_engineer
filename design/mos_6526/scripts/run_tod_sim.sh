#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/tod"
verilator --lint-only -Wall "$HERE/src/mos_6526_tod.sv"
verilator --cc --exe --build -Wall -j 4 --top-module mos_6526_tod --Mdir "$HERE/work/tod" \
    "$HERE/src/mos_6526_tod.sv" "$HERE/tb/tod_test.cpp" > "$HERE/work/tod-build.log" 2>&1
"$HERE/work/tod/Vmos_6526_tod" > "$HERE/work/tod.log" 2>&1
cat "$HERE/work/tod.log"
