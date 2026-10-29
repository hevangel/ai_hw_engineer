#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/build"
python3 "$SYSTEM/scripts/prepare_image.py" "$SYSTEM/src/rom/scelbal_sc1.bin" "$SYSTEM/build/scelbal.hex"
python3 "$SYSTEM/scripts/prepare_game_hex.py" "$SYSTEM/spec/reference/shooting_stars.bas" "$SYSTEM/build/shooting_stars.hex"
verilator --cc --exe --build -j 4 -Wno-fatal --top-module scelbi_8b \
    --Mdir "$SYSTEM/build/obj_dir" \
    "$ROOT/design/intel_mcs8/intel_8008/src/intel_8008.sv" \
    "$SYSTEM/src/scelbi_8b.sv" "$SYSTEM/host/simulator.cpp" \
    >"$SYSTEM/build/system_build.log"
export SCELBI_SIMULATOR="$SYSTEM/build/obj_dir/Vscelbi_8b"
export SCELBI_IMAGE="$SYSTEM/build/scelbal.hex"
# Inside the container the server must bind the container interface for the
# -p port mapping to reach it; exposure is gated by the host-side -p address
# (the documented command maps 127.0.0.1 only).
export SCELBI_HOST="${SCELBI_HOST:-0.0.0.0}"
exec python3 "$SYSTEM/host/server.py"
