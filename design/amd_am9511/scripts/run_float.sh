#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/float"
mkdir -p "$WORK_DIR"
(cd "$DESIGN_DIR/references/am9511" && sha256sum -c SHA256SUMS)
for source in ova floatcnv am9511; do
 cc -std=c99 -O2 -fwrapv -I"$DESIGN_DIR/references/am9511" -c "$DESIGN_DIR/references/am9511/$source.c" -o "$WORK_DIR/$source.o"
done
verilator --lint-only -Wall --top-module amd_am9511_float "$DESIGN_DIR/src/amd_am9511_float.sv" "$DESIGN_DIR/src/amd_am9511_divider.sv" > "$WORK_DIR/lint.log" 2>&1
verilator --cc --exe --build -Wall --top-module amd_am9511_float --Mdir "$WORK_DIR/obj" \
 -CFLAGS "-std=c++17 -O2 -I$DESIGN_DIR/references/am9511" -LDFLAGS "$WORK_DIR/ova.o $WORK_DIR/floatcnv.o $WORK_DIR/am9511.o -lm" \
 "$DESIGN_DIR/src/amd_am9511_float.sv" "$DESIGN_DIR/src/amd_am9511_divider.sv" "$DESIGN_DIR/tb/float_driver.cpp" > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vamd_am9511_float" > "$WORK_DIR/run.log" 2>&1
cat "$WORK_DIR/run.log"
grep -q 'TEST PASSED:' "$WORK_DIR/run.log"
