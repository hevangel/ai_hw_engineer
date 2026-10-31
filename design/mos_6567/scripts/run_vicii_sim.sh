#!/bin/sh
# VIC-II comparison with the unchanged MAME mos6566 implementation for all
# five variants, then oracle-checked dot replay in Verilator and xezim.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RECORDS=${1:-40000}
mkdir -p "$HERE/work"
python3 "$HERE/scripts/fetch_vicii_reference.py"
# The unchanged reference has one unused parameter; keep -Werror otherwise.
c++ -std=c++20 -O2 -Wall -Wextra -Wno-unused-parameter -Werror -I"$HERE/tb/mame_stubs" \
    -I"$HERE/work/reference" -c "$HERE/tb/vicii_oracle.cpp" -o "$HERE/work/vicii_oracle.o"
echo "== strict lint: all variants"
for variant in 0 1 2 3 4; do
    verilator --lint-only -Wall -GVARIANT=$variant --top-module mos_6567 "$HERE/src/mos_6567.sv"
done
: > "$HERE/work/vicii-oracle.log"
for variant in 0 1 2 3 4; do
    verilator --cc --exe --build -Wall -j 4 -O3 -GVARIANT=$variant --top-module mos_6567 \
        --Mdir "$HERE/work/vicii-$variant" "$HERE/src/mos_6567.sv" "$HERE/tb/vicii_test.cpp" \
        "$HERE/work/vicii_oracle.o" > "$HERE/work/vicii-build-$variant.log" 2>&1
    if [ "$variant" = 0 ]; then
        "$HERE/work/vicii-0/Vmos_6567" 0 1 "$HERE/work/vicii-vectors.txt" "$RECORDS" \
            >> "$HERE/work/vicii-oracle.log" 2>&1
    else
        "$HERE/work/vicii-$variant/Vmos_6567" "$variant" 1 >> "$HERE/work/vicii-oracle.log" 2>&1
    fi
    grep "MOS 6567 VIC-II ORACLE PASS: variant $variant," "$HERE/work/vicii-oracle.log"
done
COUNT=$(sed -n 's/.*variant 0,.* \([0-9]*\) replay records/\1/p' "$HERE/work/vicii-oracle.log")
test "$COUNT" = "$RECORDS"
echo "== Verilator replay"
verilator --binary --timing -Wall -Wno-TIMESCALEMOD -j 4 --top-module tb_vicii \
    --Mdir "$HERE/work/vicii-sv" "$HERE/src/mos_6567.sv" "$HERE/tb/tb_vicii.sv" \
    > "$HERE/work/vicii-sv-build.log" 2>&1
"$HERE/work/vicii-sv/Vtb_vicii" "+vectors=$HERE/work/vicii-vectors.txt" "+records=$COUNT" \
    > "$HERE/work/vicii-verilator.log" 2>&1
grep 'MOS 6567 VIC-II REPLAY PASS:' "$HERE/work/vicii-verilator.log"
echo "== xezim replay"
xezim --simulate --sv2017 --error-exit -s tb_vicii "$HERE/src/mos_6567.sv" "$HERE/tb/tb_vicii.sv" \
    "+vectors=$HERE/work/vicii-vectors.txt" "+records=$COUNT" --max-time 100000000ns \
    -l "$HERE/work/vicii-xezim.log"
grep 'MOS 6567 VIC-II REPLAY PASS:' "$HERE/work/vicii-xezim.log"
