#!/bin/sh
# Build the Verilator model of the PDP-1 Am29xx machine.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work/obj"
verilator --cc --exe --build \
    -I"$ROOT/system/pdp1_am29xx/src" -j 4 --assert --trace-fst --trace-depth 2 \
    -Wno-UNOPTFLAT -Wno-PINCONNECTEMPTY -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC \
    --top-module pdp1_am29xx --Mdir "$SYSTEM/work/obj" \
    "$ROOT/system/pdp1_am29xx/src/microcode/pdp1_uc.sv" \
    "$ROOT/system/pdp1_am29xx/src/pdp1_memory.sv" \
    "$ROOT/system/pdp1_am29xx/src/pdp1_io.sv" \
    "$ROOT/system/pdp1_am29xx/src/pdp1_datapath.sv" \
    "$ROOT/system/pdp1_am29xx/src/pdp1_microseq.sv" \
    "$ROOT/system/pdp1_am29xx/src/pdp1_am29xx.sv" \
    "$ROOT/design/amd_am29xx/amd_am2901/src/amd_am2901.sv" \
    "$ROOT/design/amd_am29xx/amd_am2901/src/amd_am2901_alu.sv" \
    "$ROOT/design/amd_am29xx/amd_am2910/src/amd_am2910.sv" \
    "$ROOT/system/pdp1_am29xx/tb/sim_main.cpp" > "$SYSTEM/work/build.log" 2>&1 || {
      tail -40 "$SYSTEM/work/build.log"; exit 1; }
echo "built $SYSTEM/work/obj/Vpdp1_am29xx"
