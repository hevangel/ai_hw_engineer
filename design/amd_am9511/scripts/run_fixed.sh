#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/fixed"
mkdir -p "$WORK_DIR"
(cd "$DESIGN_DIR/references/am9511" && sha256sum -c SHA256SUMS)
cc -std=c99 -O2 -fwrapv -I"$DESIGN_DIR/references/am9511" -c "$DESIGN_DIR/references/am9511/ova.c" -o "$WORK_DIR/ova.o"
verilator --lint-only -Wall --top-module amd_am9511_fixed "$DESIGN_DIR/src/amd_am9511_fixed.sv" > "$WORK_DIR/lint.log" 2>&1
verilator --cc --exe --build -Wall --top-module amd_am9511_fixed --Mdir "$WORK_DIR/obj" \
 -CFLAGS "-std=c++17 -O2 -I$DESIGN_DIR/references/am9511" -LDFLAGS "$WORK_DIR/ova.o" \
 "$DESIGN_DIR/src/amd_am9511_fixed.sv" "$DESIGN_DIR/tb/fixed_driver.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vamd_am9511_fixed" > "$WORK_DIR/run.log" 2>&1
cat "$WORK_DIR/run.log"
grep -q 'TEST PASSED:' "$WORK_DIR/run.log"
