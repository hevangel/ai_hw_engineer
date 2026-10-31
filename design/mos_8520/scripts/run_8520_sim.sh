#!/bin/sh
# mos_8520 versus MAME's unchanged 8520 on random traffic with a TOD pin
# clock, then replay of the cycle records in Verilator and xezim.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RECORDS=${1:-200000}
SRC="$HERE/src/mos_8520.sv $HERE/src/mos_8520_tod.sv $HERE/../mos_6526/src/mos_6526_timer.sv \
$HERE/../mos_6526/src/mos_6526_serial.sv $HERE/../mos_6526/src/mos_6526_irq.sv"
mkdir -p "$HERE/work"
python3 "$HERE/scripts/fetch_cia_reference.py"
c++ -std=c++20 -O2 -Wall -Wextra -Werror -I"$HERE/tb/mame_stubs" -I"$HERE/work/reference" \
    -c "$HERE/tb/cia_oracle.cpp" -o "$HERE/work/cia_oracle.o"
echo "== strict lint"
# shellcheck disable=SC2086
verilator --lint-only -Wall --top-module mos_8520 $SRC
echo "== MAME 8520 comparison"
# shellcheck disable=SC2086
verilator --cc --exe --build -Wall -j 4 -O3 --public-flat-rw --top-module mos_8520 \
    --Mdir "$HERE/work/cmp8520" $SRC "$HERE/tb/cia8520_compare.cpp" "$HERE/work/cia_oracle.o" \
    > "$HERE/work/cmp8520.log" 2>&1
"$HERE/work/cmp8520/Vmos_8520" 0 "$HERE/work/cia8520-vectors.txt" "$RECORDS" > "$HERE/work/8520-oracle.log" 2>&1
grep 'MOS 8520 COMPARISON:' "$HERE/work/8520-oracle.log"
# The residual classes are listed in report/final_report.md; any growth fails.
MISMATCHES=$(sed -n 's/.*reads, \([0-9]*\) mismatches.*/\1/p' "$HERE/work/8520-oracle.log")
test "$MISMATCHES" -le 9
echo "== Verilator replay"
# shellcheck disable=SC2086
verilator --binary --timing -Wall -Wno-TIMESCALEMOD -j 4 --top-module tb_cia8520 \
    --Mdir "$HERE/work/8520-sv" $SRC "$HERE/tb/tb_cia8520.sv" > "$HERE/work/8520-sv-build.log" 2>&1
"$HERE/work/8520-sv/Vtb_cia8520" "+vectors=$HERE/work/cia8520-vectors.txt" "+records=$RECORDS" \
    > "$HERE/work/8520-verilator.log" 2>&1
grep 'MOS 8520 REPLAY PASS:' "$HERE/work/8520-verilator.log"
echo "== xezim replay"
# shellcheck disable=SC2086
xezim --simulate --sv2017 --error-exit -s tb_cia8520 $SRC "$HERE/tb/tb_cia8520.sv" \
    "+vectors=$HERE/work/cia8520-vectors.txt" "+records=$RECORDS" --max-time 100000000ns \
    -l "$HERE/work/8520-xezim.log"
grep 'MOS 8520 REPLAY PASS:' "$HERE/work/8520-xezim.log"
