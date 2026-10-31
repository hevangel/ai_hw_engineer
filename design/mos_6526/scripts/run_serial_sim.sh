#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/serial"
verilator --lint-only -Wall "$HERE/src/mos_6526_serial.sv"
verilator --cc --exe --build -Wall -j 4 --top-module mos_6526_serial --Mdir "$HERE/work/serial" \
    "$HERE/src/mos_6526_serial.sv" "$HERE/tb/serial_test.cpp" > "$HERE/work/serial-build.log" 2>&1
"$HERE/work/serial/Vmos_6526_serial" > "$HERE/work/serial.log" 2>&1
cat "$HERE/work/serial.log"
