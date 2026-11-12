#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
mkdir -p "$WORK_DIR"
python3 "$SCRIPT_DIR/generate_commands.py" --check
python3 "$SCRIPT_DIR/gen_vectors.py" --random 300
verilator --cc --exe --build -Wall -I"$DESIGN_DIR/src" \
    --top-module amd_am9512 --Mdir "$WORK_DIR/obj" \
    -CFLAGS "-std=c++17 -O2" \
    "$DESIGN_DIR/src/amd_am9512.sv" \
    "$DESIGN_DIR/src/amd_am9512_fpu.sv" \
    "$DESIGN_DIR/src/amd_am9512_divider.sv" \
    "$DESIGN_DIR/tb/tb_top.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vamd_am9512" "$DESIGN_DIR/work/vectors.txt"