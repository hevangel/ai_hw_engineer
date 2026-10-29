#!/bin/sh
# Independent-oracle CPU gate: SingleStepTests 65816, every opcode in native
# and emulation mode, exact bus cycles and final state.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/cpu/obj"
if [ ! -s "$HERE/work/cpu/vectors.txt" ]; then
    python3 "$HERE/scripts/fetch_cpu_tests.py" --per-file "${PER_FILE:-500}"
fi
verilator --cc --exe --build --public-flat-rw -Wall -Wno-UNUSEDSIGNAL -O2 -j 4 --top-module wdc_65c816 \
    --Mdir "$HERE/work/cpu/obj" "$HERE/src/wdc_65c816.sv" "$HERE/tb/cpu_vector_test.cpp" \
    -CFLAGS -O2 > "$HERE/work/cpu/build.log" 2>&1 || { tail -30 "$HERE/work/cpu/build.log"; exit 1; }
"$HERE/work/cpu/obj/Vwdc_65c816" "${VECTORS:-$HERE/work/cpu/vectors.txt}" "${MAX_FAIL:-1}"
