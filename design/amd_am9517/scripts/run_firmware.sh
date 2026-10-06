#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CPU_DIR=$(dirname "$HERE")/amd_am9080
WORK_DIR="$HERE/work/firmware"
mkdir -p "$WORK_DIR"
(cd "$HERE/references" && sha256sum -c original_firmware.sha256)
cc -std=c99 -O2 -I"$CPU_DIR/references/superzazu" -c "$CPU_DIR/references/superzazu/i8080.c" -o "$WORK_DIR/i8080.o"
verilator --cc --exe --build -Wall --top-module tb_firmware --Mdir "$WORK_DIR/obj"  -CFLAGS "-std=c++17 -O2 -I$CPU_DIR/references/superzazu" -LDFLAGS "$WORK_DIR/i8080.o"  "$HERE/src/amd_am9517.sv" "$CPU_DIR/src/amd_am9080.sv" "$CPU_DIR/src/amd_am9080_alu.sv"  "$HERE/tb/tb_firmware.sv" "$HERE/tb/firmware_driver.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vtb_firmware" "$HERE/references/original_stup.hex" "$HERE/references/original_sdma.hex" > "$WORK_DIR/run.log" 2>&1
cat "$WORK_DIR/run.log"
grep -q 'TEST PASSED:' "$WORK_DIR/run.log"
