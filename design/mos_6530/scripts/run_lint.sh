#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CPU="$HERE/../mos_6502/src/mos_6502.sv"
verilator --lint-only -Wall -I"$HERE/src" --top-module mos_6530_kim \
    "$HERE/src/mos_6530.sv" "$HERE/src/mos_6530_kim.sv"
for top in tb_top tb_kim_boot; do
    extra=
    if [ "$top" = tb_kim_boot ]; then extra=$CPU; fi
    verilator --lint-only -Wall --timing -Wno-TIMESCALEMOD -I"$HERE/src" --top-module "$top" \
        "$HERE/src/mos_6530.sv" "$HERE/src/mos_6530_kim.sv" $extra "$HERE/tb/$top.sv"
done
