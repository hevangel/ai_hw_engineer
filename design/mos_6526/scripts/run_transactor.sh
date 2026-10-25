#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT="$HERE/work/transactor"
REF="$HERE/../mos_6502/work/native/netlist"
python3 "$HERE/scripts/fetch_software.py"
python3 "$HERE/scripts/fetch_transactor_reference.py"
python3 "$HERE/../mos_6502/scripts/fetch_native_netlist.py"
gcc -O2 -I"$REF" -c "$HERE/tb/cia_netlist_adapter.c" -o "$OUT/io_adapter.o"
gcc -O2 -I"$REF" -c "$REF/netlist_sim.c" -o "$OUT/netlist.o"
for profile in 1 0; do
    verilator --cc --exe --build -Wall -j 4 --top-module cia_software_top \
        -GTIMER_B_READ_LOSS="$profile" --Mdir "$OUT/profile_$profile" \
        "$HERE"/src/*.sv "$HERE/../mos_6502/src/mos_6502_native.sv" \
        "$HERE/tb/cia_software_top.sv" "$HERE/tb/cia_transactor_test.cpp" \
        -CFLAGS "-I$HERE/work/reference-chips" -LDFLAGS "$OUT/io_adapter.o $OUT/netlist.o" \
        > "$OUT/profile_$profile-build.log" 2>&1
    "$OUT/profile_$profile/Vcia_software_top" "$HERE/work/lorenz/kernal.901227-03.bin" \
        "$OUT/basic.901226-01.bin" "$OUT/ciatest64.bas" rtl "$profile" > "$OUT/profile_$profile.log" 2>&1
    grep 'MOS 6526 TRANSACTOR PASS:' "$OUT/profile_$profile.log"
done
for mode in reference netlist; do
    "$OUT/profile_1/Vcia_software_top" "$HERE/work/lorenz/kernal.901227-03.bin" \
        "$OUT/basic.901226-01.bin" "$OUT/ciatest64.bas" "$mode" 1 > "$OUT/$mode.log" 2>&1
    grep 'MOS 6526 TRANSACTOR PASS:' "$OUT/$mode.log"
done
echo 'MOS 6526 TRANSACTOR PROFILE GATES PASS (subcycle/revision captures remain)'
