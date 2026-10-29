#!/bin/sh
# Directed PPU checks for both regions on Verilator (and xezim when installed).
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/scripts/sources.sh"
mkdir -p "$HERE/work/sim"
for region in ntsc pal; do
    def=""; [ "$region" = pal ] && def="-DPAL_REGION"
    verilator --binary --timing -Wall -Wno-UNUSEDSIGNAL -Wno-TIMESCALEMOD $def -j 4 --top-module tb_top \
        --Mdir "$HERE/work/sim/$region" $RICOH_2C02_SRC "$HERE/tb/tb_top.sv" \
        > "$HERE/work/sim/$region-build.log" 2>&1 || { cat "$HERE/work/sim/$region-build.log"; exit 1; }
    "$HERE/work/sim/$region/Vtb_top" > "$HERE/work/sim/$region-verilator.log" 2>&1 || {
        tail -20 "$HERE/work/sim/$region-verilator.log"; exit 1; }
    grep 'RICOH 2C02 TB PASS' "$HERE/work/sim/$region-verilator.log"
    if command -v xezim >/dev/null 2>&1; then
        xezim --simulate --sv2017 --error-exit $def -s tb_top $RICOH_2C02_SRC "$HERE/tb/tb_top.sv" \
            -l "$HERE/work/sim/$region-xezim.log"
        grep 'RICOH 2C02 TB PASS' "$HERE/work/sim/$region-xezim.log"
    else
        echo "xezim not installed: skipped second simulator for $region"
    fi
done
