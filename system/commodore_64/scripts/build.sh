#!/bin/sh
# Build the persistent C64 RTL simulator (Verilator) used by the web panel
# and the original-software regression.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
. "$SYSTEM/scripts/sources.sh"
VARIANT=${C64_VARIANT:-0}
OBJ="$SYSTEM/work/obj_v$VARIANT"
mkdir -p "$OBJ"
verilator --cc --exe --build -j 4 -O3 --x-assign fast --x-initial fast \
    -DSIMULATION --trace-fst --trace-depth 1 -Wno-fatal -Wno-UNOPTFLAT \
    -GVARIANT="$VARIANT" -CFLAGS -DC64_VARIANT="$VARIANT" --top-module c64_board --Mdir "$OBJ" \
    $C64_SOURCES "$SYSTEM/host/simulator.cpp" > "$SYSTEM/work/build_v$VARIANT.log" 2>&1 || {
    tail -n 30 "$SYSTEM/work/build_v$VARIANT.log"; exit 1; }
echo "Built $OBJ/Vc64_board"
