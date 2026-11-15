#!/bin/sh
# Capture a VCD of the SCELBI 8B console and CPU bus during a SCELBAL session.
#
# Boots SCELBAL, types the SIMH guide's calculator program, and records the
# signals around the RUN output.  The result is build/scelbi_8b.vcd, viewable
# with `surfer build/scelbi_8b.vcd` (the image ships Surfer).
#
# The console bit-banger frames one character over ten OUTs and nine INPs, so
# the transcript also names the exact time window that holds the result:
# build/waveform_window.txt holds the start/end time of the RUN output.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/build"
python3 "$SYSTEM/scripts/prepare_image.py" "$SYSTEM/src/rom/scelbal_sc1.bin" "$SYSTEM/build/scelbal.hex"
verilator --binary --timing -Wno-fatal --trace --top-module tb_wave \
    --Mdir "$SYSTEM/build/obj_wave" \
    "$ROOT/design/intel_mcs8/intel_8008/src/intel_8008.sv" \
    "$SYSTEM/src/scelbi_8b.sv" "$SYSTEM/tb/tb_wave.sv" \
    >"$SYSTEM/build/wave_build.log"
(cd "$SYSTEM" && "$SYSTEM/build/obj_wave/Vtb_wave" "+image=$SYSTEM/build/scelbal.hex")
ls -l "$SYSTEM/build/scelbi_8b.vcd"