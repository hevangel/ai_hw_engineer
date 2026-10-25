#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CORE="$HERE/../mos_6502/src/mos_6502_native.sv"
RRIOT="$HERE/../mos_6530"
mkdir -p "$HERE/work/sim"
for top in tb_port tb_top tb_kim_boot; do
    sources="$HERE/src/mos_6510_port.sv"
    bench="$HERE/tb/$top.sv"
    marker='MOS 6510 PORT PASS:'
    if [ "$top" != tb_port ]; then sources="$CORE $sources $HERE/src/mos_6510.sv"; marker='MOS 6510 CPU PASS:'; fi
    if [ "$top" = tb_kim_boot ]; then
        sources="$sources $RRIOT/src/mos_6530.sv $RRIOT/src/mos_6530_kim.sv"
        bench="$RRIOT/tb/tb_kim_boot.sv"
        marker='KIM-1 ORIGINAL MONITOR PASS:'
    fi
    verilator --binary --timing -Wall -Wno-TIMESCALEMOD -DCPU_6510 -I"$RRIOT/src" \
        -j 4 --top-module "$top" --Mdir "$HERE/work/sim/$top" \
        $sources "$bench" > "$HERE/work/sim/$top-build.log" 2>&1
    "$HERE/work/sim/$top/V$top" > "$HERE/work/sim/$top-verilator.log" 2>&1
    grep "$marker" "$HERE/work/sim/$top-verilator.log"
    xezim --simulate --sv2017 --error-exit -DCPU_6510 -I"$RRIOT/src" -s "$top" \
        $sources "$bench" +quick --max-time 10000000ns -l "$HERE/work/sim/$top-xezim.log"
    grep "$marker" "$HERE/work/sim/$top-xezim.log"
done
