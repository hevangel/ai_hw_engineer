#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
python3 "$HERE/scripts/fetch_raster_reference.py"
python3 "$HERE/scripts/fetch_ntsc_reference.py"
cc -std=c11 -O2 -Wall -Wextra -Werror -I"$HERE/work/raster-reference" \
    -c "$HERE/tb/pal_raster_oracle.c" -o "$HERE/work/pal_raster_oracle.o"
c++ -std=c++17 -O2 -Wall -Wextra -Werror -I"$HERE/work/ntsc-reference" \
    -c "$HERE/tb/ntsc_raster_oracle.cpp" -o "$HERE/work/ntsc_raster_oracle.o"
verilator --lint-only -Wall --top-module mos_6560_raster "$HERE/src/mos_6560_raster.sv"
verilator --lint-only -Wall -GPAL=0 --top-module mos_6560_raster "$HERE/src/mos_6560_raster.sv"
verilator --cc --exe --build -Wall -j 4 --top-module raster_pair \
    --Mdir "$HERE/work/raster-native" "$HERE/src/mos_6560_raster.sv" \
    "$HERE/src/mos_6560_regs.sv" "$HERE/tb/raster_pair.sv" "$HERE/tb/raster_test.cpp" \
    "$HERE/work/pal_raster_oracle.o" "$HERE/work/ntsc_raster_oracle.o" \
    > "$HERE/work/raster-build.log" 2>&1
"$HERE/work/raster-native/Vraster_pair" "$HERE/work/raster-vectors.txt" \
    > "$HERE/work/raster-oracle.log" 2>&1
grep 'MOS 6560 RASTER ORACLE PASS:' "$HERE/work/raster-oracle.log"
RECORDS=$(sed -n 's/.*comparisons, \([0-9]*\) replay records,.*/\1/p' "$HERE/work/raster-oracle.log")
test -n "$RECORDS"
verilator --binary --timing -Wall -Wno-TIMESCALEMOD -j 4 --top-module tb_raster \
    --Mdir "$HERE/work/raster-sv" "$HERE/src/mos_6560_raster.sv" \
    "$HERE/src/mos_6560_regs.sv" "$HERE/tb/raster_pair.sv" "$HERE/tb/tb_raster.sv" \
    > "$HERE/work/raster-sv-build.log" 2>&1
"$HERE/work/raster-sv/Vtb_raster" "+vectors=$HERE/work/raster-vectors.txt" "+records=$RECORDS" \
    > "$HERE/work/raster-verilator.log" 2>&1
grep 'MOS 6560 RASTER REPLAY PASS:' "$HERE/work/raster-verilator.log"
xezim --simulate --sv2017 --error-exit -s tb_raster \
    "$HERE/src/mos_6560_raster.sv" "$HERE/src/mos_6560_regs.sv" \
    "$HERE/tb/raster_pair.sv" "$HERE/tb/tb_raster.sv" \
    "+vectors=$HERE/work/raster-vectors.txt" "+records=$RECORDS" --max-time 1000000ns \
    -l "$HERE/work/raster-xezim.log"
grep 'MOS 6560 RASTER REPLAY PASS:' "$HERE/work/raster-xezim.log"
