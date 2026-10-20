#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/fetch_firmware.py
. scripts/sources.sh
mkdir -p work/firmware
verilator --coverage-line --cc --exe --build -j 4 -Wall --top-module apple_iie --Mdir work/firmware $SOURCES "$(pwd)/tb/firmware.cpp" "$(pwd)/host/panel.c"
work/firmware/Vapple_iie
