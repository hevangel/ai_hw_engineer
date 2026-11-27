#!/bin/sh
# Build the Verilator physical-capture replay bench for intel_80386_core.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
OUT=${I386_BUILD_DIR:-$DESIGN_DIR/work/verilator}
mkdir -p "$OUT"
echo "=== Building intel_80386_core replay bench in $OUT ==="
verilator --cc --exe --build -O2 -j 0 -Wall -Wno-fatal --top-module intel_80386_core \
  -Mdir "$OUT" -o replay \
  "$DESIGN_DIR/src/intel_80386_pkg.sv" "$DESIGN_DIR/src/intel_80386_decode.sv" \
  "$DESIGN_DIR/src/intel_80386_divider.sv" "$DESIGN_DIR/src/intel_80386_core.sv" \
  "$DESIGN_DIR/tb/tb_replay.cpp" > "$OUT/build.log" 2>&1 || { tail -40 "$OUT/build.log"; exit 1; }
echo "=== Built $OUT/replay ==="
