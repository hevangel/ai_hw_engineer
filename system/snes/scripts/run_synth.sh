#!/bin/sh
# Yosys synthesis check for the SNES board logic with all of its chips.
# The snes_memory storage model is an external interface (blackbox).
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
. "$SYSTEM/scripts/sources.sh"
mkdir -p "$SYSTEM/work/synth"
yosys -Q -l "$SYSTEM/work/synth/snes.log" -p "read_verilog -sv $SNES_INC $SNES_CHIP_SRC $SNES_BOARD_SRC; \
    read_verilog -lib $SYSTEM/synth/snes_memory_stub.v; \
    hierarchy -check -top snes; synth -noabc -top snes; \
    abc -script +strash,map; check -assert; stat" > /dev/null
grep -A3 "Number of cells" "$SYSTEM/work/synth/snes.log" | tail -4
echo "Synthesis OK (log: $SYSTEM/work/synth/snes.log)"
