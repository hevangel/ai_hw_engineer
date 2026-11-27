#!/bin/sh
# 80287 regression: the shared x87 controller built with VARIANT=1 runs the
# shared 8087 suite (host-x87 arithmetic oracle, Intel ARRSUM software,
# formats, stalls, save/restore) with the 80287's documented differences,
# plus the 80287-only directed tests in tb/tb_80287_extra.hpp.
set -eu
D=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
X87=$(CDPATH= cd -- "$D/../intel_8087" && pwd)
OUT=$D/work/sim
mkdir -p "$OUT"
echo "Intel 80287: build shared x87 controller (VARIANT=1) and regression"
verilator --cc --exe --build -j 4 -Wall --assert -GVARIANT=1 -GAW=32 -I"$X87/src" \
    --top-module intel_8087 --Mdir "$OUT" -o tb_80287 \
    -CFLAGS "-std=c++17 -O2 -frounding-math -fno-fast-math -DX87_VARIANT=1 -DX87_EXTRA_TESTS=\\\"$D/tb/tb_80287_extra.hpp\\\"" \
    "$X87/src/intel_8087_alu.sv" "$X87/src/intel_8087_trans.sv" "$X87/src/intel_8087.sv" \
    "$X87/tb/test_8087.cpp" > "$OUT/build.log" 2>&1 || { tail -30 "$OUT/build.log"; exit 1; }
"$OUT/tb_80287"
