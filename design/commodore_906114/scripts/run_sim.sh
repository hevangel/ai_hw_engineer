#!/bin/sh
# Exhaustive 65,536-word dump in Verilator and Icarus, compared with the
# map derived from unchanged VICE sources.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
python3 "$HERE/scripts/fetch_reference.py"
verilator --binary -Wall --top-module tb_top --Mdir "$HERE/work/obj" -o Vtb \
    "$HERE/src/commodore_906114.sv" "$HERE/tb/tb_top.sv" > "$HERE/work/build.log" 2>&1
"$HERE/work/obj/Vtb" "+out=$HERE/work/dump_verilator.txt"
iverilog -g2012 -o "$HERE/work/tb.vvp" "$HERE/src/commodore_906114.sv" "$HERE/tb/tb_top.sv"
vvp -n "$HERE/work/tb.vvp" "+out=$HERE/work/dump_icarus.txt"
python3 "$HERE/scripts/pla_oracle.py" "$HERE/work/dump_verilator.txt" "$HERE/work/dump_icarus.txt"
echo 'COMMODORE 906114 SIMULATION PASS'
