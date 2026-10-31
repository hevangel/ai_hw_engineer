#!/bin/sh
# Complete-VIC comparison with unchanged MAME display/bus/light-pen/sound
# functions, then oracle-vector replay in Verilator and xezim.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RECORDS=${1:-200000}
SRC="$HERE/src/mos_6560.sv $HERE/src/mos_6560_regs.sv $HERE/src/mos_6560_raster.sv \
$HERE/src/mos_6560_video.sv $HERE/src/mos_6560_lightpen.sv $HERE/src/mos_6560_audio.sv"
mkdir -p "$HERE/work"
python3 "$HERE/scripts/fetch_ntsc_reference.py"
c++ -std=c++17 -O2 -Wall -Wextra -Werror -I"$HERE/work/ntsc-reference" \
    -c "$HERE/tb/vic_display_oracle.cpp" -o "$HERE/work/vic_display_oracle.o"
echo "== strict lint: complete VIC, PAL and NTSC profiles"
for profile in 1 0; do
    # shellcheck disable=SC2086
    verilator --lint-only -Wall -GPAL=$profile --top-module mos_6560 $SRC
done
echo "== native oracle comparison"
# shellcheck disable=SC2086
verilator --cc --exe --build -Wall -j 4 --top-module vic_pair \
    --Mdir "$HERE/work/vic-native" $SRC "$HERE/tb/vic_pair.sv" \
    "$HERE/tb/vic_test.cpp" "$HERE/work/vic_display_oracle.o" \
    > "$HERE/work/vic-build.log" 2>&1
"$HERE/work/vic-native/Vvic_pair" "$HERE/work/vic-vectors.txt" "$RECORDS" \
    > "$HERE/work/vic-oracle.log" 2>&1
grep 'MOS 6560 VIC ORACLE PASS:' "$HERE/work/vic-oracle.log"
grep '^coverage:' "$HERE/work/vic-oracle.log"
COUNT=$(sed -n 's/.*comparisons, \([0-9]*\) replay records.*/\1/p' "$HERE/work/vic-oracle.log")
test "$COUNT" = "$RECORDS"
echo "== Verilator replay"
# shellcheck disable=SC2086
verilator --binary --timing -Wall -Wno-TIMESCALEMOD -j 4 --top-module tb_vic \
    --Mdir "$HERE/work/vic-sv" $SRC "$HERE/tb/vic_pair.sv" "$HERE/tb/tb_vic.sv" \
    > "$HERE/work/vic-sv-build.log" 2>&1
"$HERE/work/vic-sv/Vtb_vic" "+vectors=$HERE/work/vic-vectors.txt" "+records=$COUNT" \
    > "$HERE/work/vic-verilator.log" 2>&1
grep 'MOS 6560 VIC REPLAY PASS:' "$HERE/work/vic-verilator.log"
echo "== xezim replay"
# shellcheck disable=SC2086
xezim --simulate --sv2017 --error-exit -s tb_vic $SRC \
    "$HERE/tb/vic_pair.sv" "$HERE/tb/tb_vic.sv" \
    "+vectors=$HERE/work/vic-vectors.txt" "+records=$COUNT" --max-time 10000000ns \
    -l "$HERE/work/vic-xezim.log"
grep 'MOS 6560 VIC REPLAY PASS:' "$HERE/work/vic-xezim.log"
