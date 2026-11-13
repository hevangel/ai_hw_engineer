#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
mkdir -p "$WORK_DIR"
verilator --cc --exe --build -Wall -I"$DESIGN_DIR/src" \
    --top-module amd_am9513 --Mdir "$WORK_DIR/obj" \
    -CFLAGS "-std=c++17 -O2" \
    "$DESIGN_DIR/src/amd_am9513.sv" \
    "$DESIGN_DIR/tb/tb_top.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vamd_am9513"