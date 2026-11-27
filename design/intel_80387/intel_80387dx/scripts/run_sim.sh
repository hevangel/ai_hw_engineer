#!/bin/sh
# 80387 architectural regression: shared x87 controller built with
# VARIANT=2, checked against the build host's x87 FPU (independent oracle).
# Usage: run_sim.sh [cases_per_instruction [seed]]   (default 2000, fixed seed)
set -eu
D=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC=$(CDPATH= cd -- "$D/../../intel_8087/src" && pwd)
OUT=$D/work/sim
mkdir -p "$OUT"
case "$(uname -m)" in x86_64|i?86) ;; *) echo "FAIL: needs an x86 host x87 FPU as oracle"; exit 1;; esac
echo "Intel 80387: build shared x87 controller (VARIANT=2) and host-oracle regression"
verilator --cc --exe --build -j 4 -Wall --assert -GVARIANT=2 -GAW=32 -I"$SRC" \
    --top-module intel_8087 --Mdir "$OUT" -o tb_80387 \
    -CFLAGS '-std=c++17 -O2 -frounding-math -fno-fast-math' \
    "$SRC/intel_8087_alu.sv" "$SRC/intel_8087_trans.sv" "$SRC/intel_8087.sv" \
    "$D/tb/tb_80387.cpp" > "$OUT/build.log" 2>&1 || { tail -30 "$OUT/build.log"; exit 1; }
"$OUT/tb_80387" "${1:-2000}" "${2:-0x803871987}"
