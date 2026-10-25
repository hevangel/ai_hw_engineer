#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/build"
python3 "$SYSTEM/scripts/prepare_image.py" "$SYSTEM/src/rom/scelbal_sc1.bin" "$SYSTEM/build/scelbal.hex"
python3 "$SYSTEM/scripts/prepare_game_hex.py" "$SYSTEM/spec/reference/shooting_stars.bas" "$SYSTEM/build/shooting_stars.hex"
verilator --lint-only -Wall --top-module scelbi_8b \
  "$ROOT/design/intel_8008/src/intel_8008.sv" "$SYSTEM/src/scelbi_8b.sv"
verilator --binary --timing -Wno-fatal --top-module tb_game \
    --Mdir "$SYSTEM/build/obj_game" \
    "$ROOT/design/intel_8008/src/intel_8008.sv" \
    "$SYSTEM/src/scelbi_8b.sv" "$SYSTEM/tb/tb_game.sv" \
    >"$SYSTEM/build/game_build.log"
(cd "$ROOT" && "$SYSTEM/build/obj_game/Vtb_game" "+image=$SYSTEM/build/scelbal.hex")
verilator --binary --timing -Wno-fatal --top-module tb_calc \
    --Mdir "$SYSTEM/build/obj_calc" \
    "$ROOT/design/intel_8008/src/intel_8008.sv" \
    "$SYSTEM/src/scelbi_8b.sv" "$SYSTEM/tb/tb_calc.sv" \
    >"$SYSTEM/build/calc_build.log"
(cd "$ROOT" && "$SYSTEM/build/obj_calc/Vtb_calc" "+image=$SYSTEM/build/scelbal.hex")
