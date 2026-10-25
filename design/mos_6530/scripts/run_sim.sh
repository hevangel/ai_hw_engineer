#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/sim"
cd "$HERE"
for top in tb_top tb_kim_boot; do
    extra=
    marker='MOS 6530 PASS:'
    if [ "$top" = tb_kim_boot ]; then
        extra="$HERE/../mos_6502/src/mos_6502.sv"
        marker='KIM-1 ORIGINAL MONITOR PASS:'
    fi
    verilator --binary --timing -Wall -Wno-TIMESCALEMOD -I"$HERE/src" -j 4 --top-module "$top" \
        --Mdir "$HERE/work/sim/$top" "$HERE/src/mos_6530.sv" "$HERE/src/mos_6530_kim.sv" \
        $extra "$HERE/tb/$top.sv" > "$HERE/work/sim/$top-build.log" 2>&1
    "$HERE/work/sim/$top/V$top" > "$HERE/work/sim/$top-verilator.log" 2>&1
    grep "$marker" "$HERE/work/sim/$top-verilator.log"
    xezim --simulate --sv2017 --error-exit -I"$HERE/src" -s "$top" \
        "$HERE/src/mos_6530.sv" "$HERE/src/mos_6530_kim.sv" $extra "$HERE/tb/$top.sv" \
        +quick --max-time 4000000ns -l "$HERE/work/sim/$top-xezim.log"
    grep "$marker" "$HERE/work/sim/$top-xezim.log"
done
