#!/bin/sh
# SID digital-core comparison with the unchanged reSIDfp engine for both
# models, then oracle-checked clock replay in Verilator and xezim.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RECORDS=${1:-30000}
R="$HERE/work/reference"
mkdir -p "$HERE/work/residfp-obj"
python3 "$HERE/scripts/fetch_sid_reference.py"
# The unchanged GPL oracle is built without warnings-as-errors; the
# project-authored adapter keeps -Werror.
for f in "$R"/*.cpp "$R/resample/SincResampler.cpp" "$R/version.cc"; do
    c++ -std=c++17 -O2 -w -I"$R" -I"$R/residfp" -c "$f" \
        -o "$HERE/work/residfp-obj/$(basename "$f").o"
done
rm -f "$HERE/work/libresidfp.a"
ar rcs "$HERE/work/libresidfp.a" "$HERE"/work/residfp-obj/*.o
c++ -std=c++17 -O2 -Wall -Wextra -Werror -I"$R" -I"$R/residfp" \
    -c "$HERE/tb/sid_oracle.cpp" -o "$HERE/work/sid_oracle.o"
echo "== strict lint: 6581 and 8580"
for model in 0 1; do
    verilator --lint-only -Wall -GMOS8580=$model --top-module mos_6581 "$HERE/src/mos_6581.sv"
done
: > "$HERE/work/sid-oracle.log"
for model in 0 1; do
    verilator --cc --exe --build -Wall -j 4 -O3 --public-flat-rw -GMOS8580=$model \
        --top-module mos_6581 --Mdir "$HERE/work/sid-$model" "$HERE/src/mos_6581.sv" \
        "$HERE/tb/sid_test.cpp" "$HERE/work/sid_oracle.o" "$HERE/work/libresidfp.a" \
        > "$HERE/work/sid-build-$model.log" 2>&1
    if [ "$model" = 0 ]; then
        SID_SR_CHECK=1 "$HERE/work/sid-0/Vmos_6581" 0 1 "$HERE/work/sid-vectors.txt" "$RECORDS" \
            >> "$HERE/work/sid-oracle.log" 2>&1
    else
        SID_SR_CHECK=1 "$HERE/work/sid-1/Vmos_6581" 1 1 >> "$HERE/work/sid-oracle.log" 2>&1
    fi
done
grep 'MOS 6581 SID ORACLE PASS: model 6581' "$HERE/work/sid-oracle.log"
grep 'MOS 6581 SID ORACLE PASS: model 8580' "$HERE/work/sid-oracle.log"
COUNT=$(sed -n 's/.*model 6581,.* \([0-9]*\) replay records/\1/p' "$HERE/work/sid-oracle.log")
test "$COUNT" = "$RECORDS"
echo "== Verilator replay"
verilator --binary --timing -Wall -Wno-TIMESCALEMOD -j 4 --top-module tb_sid \
    --Mdir "$HERE/work/sid-sv" "$HERE/src/mos_6581.sv" "$HERE/tb/tb_sid.sv" \
    > "$HERE/work/sid-sv-build.log" 2>&1
"$HERE/work/sid-sv/Vtb_sid" "+vectors=$HERE/work/sid-vectors.txt" "+records=$COUNT" \
    > "$HERE/work/sid-verilator.log" 2>&1
grep 'MOS 6581 SID REPLAY PASS:' "$HERE/work/sid-verilator.log"
echo "== xezim replay"
xezim --simulate --sv2017 --error-exit -s tb_sid "$HERE/src/mos_6581.sv" "$HERE/tb/tb_sid.sv" \
    "+vectors=$HERE/work/sid-vectors.txt" "+records=$COUNT" --max-time 100000000ns \
    -l "$HERE/work/sid-xezim.log"
grep 'MOS 6581 SID REPLAY PASS:' "$HERE/work/sid-xezim.log"
