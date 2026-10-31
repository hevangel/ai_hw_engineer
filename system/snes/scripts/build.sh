#!/bin/sh
# Build the persistent SNES RTL simulators (NTSC and PAL boards).
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
. "$SYSTEM/scripts/sources.sh"
mkdir -p "$SYSTEM/work"
: > "$SYSTEM/work/build.log"
for region in ${SNES_REGIONS:-0 1}; do
    obj="$SYSTEM/work/obj"; [ "$region" = 1 ] && obj="$SYSTEM/work/obj_pal"
    # --trace-fst records every chip-internal signal for the Surfer viewer.
    verilator --cc --exe --build -j 4 -O3 --x-assign fast --x-initial fast \
        --trace-fst --trace-depth 3 -Wno-WIDTH -Wno-fatal $SNES_INC \
        -GPAL=1\'b$region -CFLAGS "-O3 -DSNES_REGION=$region" \
        --top-module snes --Mdir "$obj" $SNES_SRC "$SYSTEM/host/simulator.cpp" \
        >> "$SYSTEM/work/build.log" 2>&1
done
echo "Built $SYSTEM/work/obj/Vsnes (NTSC) and $SYSTEM/work/obj_pal/Vsnes (PAL)"
