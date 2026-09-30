#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/build"
python3 "$SYSTEM/scripts/prepare_image.py" "$SYSTEM/src/rom/mo5_input_output.bin" "$SYSTEM/build/mo5_input_output.hex"
python3 "$SYSTEM/scripts/prepare_image.py" "$SYSTEM/src/rom/mo5_hello_world.bin" "$SYSTEM/build/mo5_hello_world.hex"
verilator --binary --timing -Wno-fatal --top-module tb_top \
    --Mdir "$SYSTEM/build/obj_test" \
    "$ROOT/design/intel_8008/src/intel_8008.sv" \
    "$SYSTEM/src/micral_n.sv" "$SYSTEM/tb/tb_top.sv" \
    >"$SYSTEM/build/test_build.log"
"$SYSTEM/build/obj_test/Vtb_top" "+image=$SYSTEM/build/mo5_input_output.hex"
verilator --binary --timing -Wno-fatal --top-module tb_hello \
    --Mdir "$SYSTEM/build/obj_hello" \
    "$ROOT/design/intel_8008/src/intel_8008.sv" \
    "$SYSTEM/src/micral_n.sv" "$SYSTEM/tb/tb_hello.sv" \
    >"$SYSTEM/build/hello_build.log"
"$SYSTEM/build/obj_hello/Vtb_hello" "+image=$SYSTEM/build/mo5_hello_world.hex"
