#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
CPU_DIR=$(dirname "$DESIGN_DIR")/amd_am9080
WORK_DIR="$DESIGN_DIR/work/firmware"
mkdir -p "$WORK_DIR"
(cd "$DESIGN_DIR/references" && sha256sum -c original_host.sha256)
cc -std=c99 -O2 -I"$CPU_DIR/references/superzazu" -c "$CPU_DIR/references/superzazu/i8080.c" -o "$WORK_DIR/i8080.o"
verilator --cc --exe --build -Wall -I"$DESIGN_DIR/src" --top-module tb_top --Mdir "$WORK_DIR/obj" \
 -CFLAGS "-std=c++17 -O2 -I$CPU_DIR/references/superzazu" -LDFLAGS "$WORK_DIR/i8080.o" \
 "$DESIGN_DIR"/src/*.sv "$CPU_DIR/src/amd_am9080.sv" "$CPU_DIR/src/amd_am9080_alu.sv" \
 "$DESIGN_DIR/tb/tb_top.sv" "$DESIGN_DIR/tb/firmware_driver.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vtb_top" "$DESIGN_DIR/references/original_host.hex" > "$WORK_DIR/run.log" 2>&1
cat "$WORK_DIR/run.log"
grep -q 'TEST PASSED:' "$WORK_DIR/run.log"
