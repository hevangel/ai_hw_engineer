#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/native/control"
verilator --cc --exe --build --public-flat-rw -Wall -j 4 --top-module mos_6502_native \
    --Mdir "$HERE/work/native/control" "$HERE/src/mos_6502_native.sv" "$HERE/tb/native_control_test.cpp" \
    > "$HERE/work/native/control-build.log" 2>&1
"$HERE/work/native/control/Vmos_6502_native" "$HERE/references/6502_functional_test.bin.hex" \
    > "$HERE/work/native/control.log" 2>&1
grep 'NATIVE NMOS CONTROL PASS:' "$HERE/work/native/control.log"
grep 'NATIVE NMOS KLAUS PASS:' "$HERE/work/native/control.log"
