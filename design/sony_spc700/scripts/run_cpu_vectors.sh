#!/bin/sh
# Independent-oracle CPU gate: SingleStepTests spc700, every opcode, exact
# bus cycles and final state.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/cpu/obj"
if [ ! -s "$HERE/work/cpu/vectors.txt" ]; then
    python3 "$HERE/scripts/fetch_cpu_tests.py"
fi
verilator --cc --exe --build --public-flat-rw -Wall -Wno-UNUSEDSIGNAL -O2 -j 4 --top-module sony_spc700 \
    --Mdir "$HERE/work/cpu/obj" "$HERE/src/sony_spc700.sv" "$HERE/tb/cpu_vector_test.cpp" \
    -CFLAGS -O2 > "$HERE/work/cpu/build.log" 2>&1 || { grep -E "%(Error|Warning)" "$HERE/work/cpu/build.log" | head -30; exit 1; }
"$HERE/work/cpu/obj/Vsony_spc700" "$HERE/work/cpu/vectors.txt" "${MAX_FAIL:-300}"
