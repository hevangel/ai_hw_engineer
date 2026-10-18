#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$SYSTEM/work/controller"
verilator --cc --exe --build -j 4 -Wall --assert --top-module xt_fixed_disk \
 --Mdir "$SYSTEM/work/controller" "$SYSTEM/src/xt_fixed_disk.sv" "$SYSTEM/tb/test_fixed_disk.cpp" \
 > "$SYSTEM/work/controller/build.log" 2>&1
"$SYSTEM/work/controller/Vxt_fixed_disk"
