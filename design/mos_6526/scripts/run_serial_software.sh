#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/serial_software"
python3 "$HERE/scripts/fetch_serial_software.py"
verilator --cc --exe --build -Wall -j 4 --top-module cia_software_top \
    --Mdir "$HERE/work/serial_software" "$HERE"/src/*.sv \
    "$HERE/../mos_6502/src/mos_6502_native.sv" "$HERE/tb/cia_software_top.sv" \
    "$HERE/tb/cia_serial_software_test.cpp" > "$HERE/work/serial-software-build.log" 2>&1
"$HERE/work/serial_software/Vcia_software_top" "$HERE/work/independent/cia-sdr-delay.prg" \
    > "$HERE/work/serial-software.log" 2>&1
"$HERE/work/serial_software/Vcia_software_top" --load "$HERE/work/independent/cia-sdr-load.prg" \
    >> "$HERE/work/serial-software.log" 2>&1
cat "$HERE/work/serial-software.log"
