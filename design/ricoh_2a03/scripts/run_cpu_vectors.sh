#!/bin/sh
# Independent-oracle CPU gate: SingleStepTests nes6502 through the full chip.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/scripts/sources.sh"
mkdir -p "$HERE/work/cpu/obj"
if [ ! -s "$HERE/work/cpu/vectors.txt" ]; then
    python3 "$HERE/scripts/fetch_cpu_tests.py" --per-opcode "${PER_OPCODE:-1000}"
fi
verilator --cc --exe --build --public-flat-rw -Wall -Wno-UNUSEDSIGNAL -O2 -j 4 --top-module ricoh_2a03 \
    --Mdir "$HERE/work/cpu/obj" $RICOH_2A03_SRC "$HERE/tb/cpu_vector_test.cpp" \
    > "$HERE/work/cpu/build.log" 2>&1
"$HERE/work/cpu/obj/Vricoh_2a03" "$HERE/work/cpu/vectors.txt" > "$HERE/work/cpu/run.log" 2>&1 || {
    cat "$HERE/work/cpu/run.log"; exit 1; }
grep 'RICOH 2A03 CPU VECTOR PASS:' "$HERE/work/cpu/run.log"
