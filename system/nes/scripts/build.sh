#!/bin/sh
# Build the persistent NES RTL simulators (NTSC and PAL boards).
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
. "$SYSTEM/scripts/sources.sh"
mkdir -p "$SYSTEM/work"
: > "$SYSTEM/work/build.log"
for region in 0 1; do
    obj="$SYSTEM/work/obj"; [ "$region" = 1 ] && obj="$SYSTEM/work/obj_pal"
    # --trace-fst records every chip-internal signal for the Surfer viewer
    # (no --public-flat-rw: it costs ~2.5x in simulation speed). The chips
    # are verified by their own suites under design/.
    verilator --cc --exe --build -j 4 -O3 --x-assign fast --x-initial fast \
        --trace-fst --trace-depth 3 \
        -GREGION=1\'b$region -CFLAGS "-O3 -DNES_REGION=$region" \
        --top-module nes --Mdir "$obj" $NES_SRC "$SYSTEM/host/simulator.cpp" \
        >> "$SYSTEM/work/build.log" 2>&1
done
echo "Built $SYSTEM/work/obj/Vnes (NTSC) and $SYSTEM/work/obj_pal/Vnes (PAL)"
