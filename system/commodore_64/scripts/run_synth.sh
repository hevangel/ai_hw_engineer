#!/bin/sh
# Yosys synthesis check for the C64 board logic and every chip on it
# (6510, two 6526s, VIC-II, SID, PLA). The c64_memory storage model is an
# external interface (blackbox).
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
. "$SYSTEM/scripts/sources.sh"
mkdir -p "$SYSTEM/work/synth"
LOGIC=$(printf '%s\n' $C64_SOURCES | grep -v '/c64_memory.sv$' | tr '\n' ' ')
"${YOSYS:-yosys}" -Q -l "$SYSTEM/work/synth/commodore_64.log" -p "read_verilog -sv $LOGIC; \
    read_verilog -lib -sv $SYSTEM/synth/c64_memory_stub.v; \
    hierarchy -check -top c64_board; synth -noabc -top c64_board; \
    abc -script +strash,map; check -assert; stat" > /dev/null
grep -E "^ +[0-9]+ cells$" "$SYSTEM/work/synth/commodore_64.log" | tail -1
echo "Synthesis OK (log: $SYSTEM/work/synth/commodore_64.log)"
