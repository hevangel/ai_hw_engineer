#!/bin/sh
# Cross-simulator real-software regression for the new native cycle engine.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RRIOT="$HERE/../mos_6530"
mkdir -p "$HERE/work/native/kim"
verilator --binary --timing -Wall -Wno-TIMESCALEMOD -DNATIVE_CPU -I"$RRIOT/src" \
    -j 4 --top-module tb_kim_boot --Mdir "$HERE/work/native/kim/obj" \
    "$HERE/src/mos_6502_native.sv" "$RRIOT/src/mos_6530.sv" \
    "$RRIOT/src/mos_6530_kim.sv" "$RRIOT/tb/tb_kim_boot.sv" \
    > "$HERE/work/native/kim/build.log" 2>&1
"$HERE/work/native/kim/obj/Vtb_kim_boot" > "$HERE/work/native/kim/verilator.log" 2>&1
grep 'KIM-1 ORIGINAL MONITOR PASS:' "$HERE/work/native/kim/verilator.log"
xezim --simulate --sv2017 --error-exit -DNATIVE_CPU -I"$RRIOT/src" -s tb_kim_boot \
    "$HERE/src/mos_6502_native.sv" "$RRIOT/src/mos_6530.sv" \
    "$RRIOT/src/mos_6530_kim.sv" "$RRIOT/tb/tb_kim_boot.sv" \
    --max-time 1000000ns -l "$HERE/work/native/kim/xezim.log"
grep 'KIM-1 ORIGINAL MONITOR PASS:' "$HERE/work/native/kim/xezim.log"
