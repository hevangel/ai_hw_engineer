#!/bin/sh
# Run the paper-tape reader testbench (rebuild + bounded run).
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/build"
rm -rf "$SYSTEM/build/obj_ptr"
verilator --binary --timing -Wno-fatal --top-module tb_ptr \
    --Mdir "$SYSTEM/build/obj_ptr" \
    "$ROOT/design/intel_mcs8/intel_8008/src/intel_8008.sv" \
    "$SYSTEM/src/scelbi_8b.sv" "$SYSTEM/tb/tb_ptr.sv" \
    >"$SYSTEM/build/ptr_build.log" 2>&1 || { cat "$SYSTEM/build/ptr_build.log"; exit 1; }
timeout 120 "$SYSTEM/build/obj_ptr/Vtb_ptr"