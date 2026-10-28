#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/build"
python3 "$SYSTEM/scripts/prepare_image.py" "$SYSTEM/src/rom/mo5_input_output.bin" "$SYSTEM/build/mo5_input_output.hex"
verilator --cc --exe --build -j 4 -Wno-fatal --top-module micral_n \
    --Mdir "$SYSTEM/build/obj_dir" \
    "$ROOT/design/intel_8008/src/intel_8008.sv" \
    "$SYSTEM/src/micral_n.sv" "$SYSTEM/host/simulator.cpp" \
    >"$SYSTEM/build/system_build.log"
export MICRAL_SIMULATOR="$SYSTEM/build/obj_dir/Vmicral_n"
export MICRAL_IMAGE="$SYSTEM/build/mo5_input_output.hex"
# Inside the container the server must bind the container interface for the
# -p port mapping to reach it; exposure is gated by the host-side -p address
# (the documented command maps 127.0.0.1 only).
export MICRAL_HOST="${MICRAL_HOST:-0.0.0.0}"
exec python3 "$SYSTEM/host/server.py"
