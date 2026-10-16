#!/bin/sh
set -eu
D=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$D/work/sim"
echo 'Intel 8087: build independent numeric and architecture regression'
verilator --cc --exe --build -j 4 -Wall --assert -I"$D/src" \
    --top-module intel_8087 --Mdir "$D/work/sim" \
    -CFLAGS '-std=c++17 -O2 -frounding-math -fno-fast-math' \
    "$D/src/"*.sv "$D/tb/test_8087.cpp" > "$D/work/sim/build.log" 2>&1
"$D/work/sim/Vintel_8087" "$@"
