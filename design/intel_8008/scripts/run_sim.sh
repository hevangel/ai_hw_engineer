#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$ROOT/build"
verilator --binary --timing -Wno-fatal --top-module tb_top \
  --Mdir "$ROOT/build/obj_directed" "$ROOT/src/intel_8008.sv" "$ROOT/tb/tb_top.sv" \
  >"$ROOT/build/directed_build.log"
"$ROOT/build/obj_directed/Vtb_top"
python3 "$ROOT/scripts/make_scelbal_vectors.py" "$ROOT/build"
verilator --binary --timing -Wno-fatal --top-module tb_scelbal \
  --Mdir "$ROOT/build/obj_scelbal" "$ROOT/src/intel_8008.sv" "$ROOT/tb/tb_scelbal.sv" \
  >"$ROOT/build/scelbal_build.log"
(cd "$ROOT/../.." && "$ROOT/build/obj_scelbal/Vtb_scelbal")
