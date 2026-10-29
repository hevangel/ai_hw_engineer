#!/bin/sh
# Independent-oracle gate: lock-step against blargg's cycle-accurate SPC_DSP.
# Usage: run_oracle.sh [seeds] [samples_per_seed]
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$HERE/scripts/fetch_oracle.py"
mkdir -p "$HERE/work/oracle/obj"
verilator --cc --exe --build --public-flat-rw -Wall -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -O2 -j 4 \
    --top-module sony_s_dsp -I"$HERE/src" --Mdir "$HERE/work/oracle/obj" \
    "$HERE/src/sony_s_dsp.sv" "$HERE/tb/dsp_oracle_test.cpp" "$HERE/work/oracle/apu/bapu/dsp/SPC_DSP.cpp" \
    -CFLAGS "-O2 -I$HERE/work/oracle -I$HERE/work/oracle/apu/bapu/dsp" \
    > "$HERE/work/oracle/build.log" 2>&1 || { grep -E "%(Error|Warning)|error" "$HERE/work/oracle/build.log" | head -30; exit 1; }
"$HERE/work/oracle/obj/Vsony_s_dsp" "${1:-20}" "${2:-2000}"
