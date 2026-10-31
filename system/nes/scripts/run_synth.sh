#!/bin/sh
# Yosys synthesis check for the NES board logic with its 2A03 and 2C02.
# The nes_memory storage model is an external interface (blackbox).
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
. "$SYSTEM/scripts/sources.sh"
mkdir -p "$SYSTEM/work/synth"
yosys -Q -l "$SYSTEM/work/synth/nes.log" -p "read_verilog -sv $NES_CHIP_SRC $NES_BOARD_SRC; \
    read_verilog -lib $SYSTEM/synth/nes_memory_stub.v; \
    hierarchy -check -top nes; synth -noabc -top nes; \
    abc -script +strash,map; check -assert; stat" > /dev/null
grep -A3 "Number of cells" "$SYSTEM/work/synth/nes.log" | tail -4
echo "Synthesis OK (log: $SYSTEM/work/synth/nes.log)"
