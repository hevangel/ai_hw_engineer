#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CORE="$HERE/../mos_6502/src/mos_6502_native.sv"
RRIOT="$HERE/../mos_6530"
mkdir -p "$HERE/work/sim"
for top in tb_top tb_kim_boot; do
    extra=
    bench="$HERE/tb/tb_top.sv"
    marker='MOS 6507 PASS:'
    if [ "$top" = tb_kim_boot ]; then
        extra="$RRIOT/src/mos_6530.sv $RRIOT/src/mos_6530_kim.sv"
        bench="$RRIOT/tb/tb_kim_boot.sv"
        marker='KIM-1 ORIGINAL MONITOR PASS:'
    fi
    verilator --binary --timing -Wall -Wno-TIMESCALEMOD -DCPU_6507 -I"$RRIOT/src" \
        -j 4 --top-module "$top" --Mdir "$HERE/work/sim/$top" \
        "$CORE" "$HERE/src/mos_6507.sv" $extra "$bench" > "$HERE/work/sim/$top-build.log" 2>&1
    "$HERE/work/sim/$top/V$top" > "$HERE/work/sim/$top-verilator.log" 2>&1
    grep "$marker" "$HERE/work/sim/$top-verilator.log"
    xezim --simulate --sv2017 --error-exit -DCPU_6507 -I"$RRIOT/src" -s "$top" \
        "$CORE" "$HERE/src/mos_6507.sv" $extra "$bench" \
        --max-time 1000000ns -l "$HERE/work/sim/$top-xezim.log"
    grep "$marker" "$HERE/work/sim/$top-xezim.log"
done
