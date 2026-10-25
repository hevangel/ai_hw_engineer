#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/tod_software"
python3 "$HERE/scripts/fetch_tod_software.py"
verilator --cc --exe --build -Wall -j 4 --top-module cia_software_top \
    --Mdir "$HERE/work/tod_software" "$HERE"/src/*.sv \
    "$HERE/../mos_6502/src/mos_6502_native.sv" "$HERE/tb/cia_software_top.sv" \
    "$HERE/tb/cia_tod_software_test.cpp" > "$HERE/work/tod-software-build.log" 2>&1
"$HERE/work/tod_software/Vcia_software_top" "$HERE/work/tod-independent/read-latch.prg" \
    "$HERE/work/tod-independent/write-stop.prg" > "$HERE/work/tod-software.log" 2>&1
cat "$HERE/work/tod-software.log"
