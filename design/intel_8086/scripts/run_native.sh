#!/bin/sh
set -eu
unset I8086_VECTOR_PREFIX
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/native"
verilator --cc --exe --build -j 4 --assert --public-flat-rw -Wall \
    --top-module intel_8086_chip --Mdir "$DESIGN_DIR/work/native" \
    "$DESIGN_DIR/src/"*.sv "$DESIGN_DIR/tb/tb_native.cpp" \
    > "$DESIGN_DIR/work/native/build.log" 2>&1
"$DESIGN_DIR/work/native/Vintel_8086_chip" > "$DESIGN_DIR/work/native/tests.log" 2>&1
cat "$DESIGN_DIR/work/native/tests.log"
grep -q '^PASS: .* native minimum/maximum-mode' "$DESIGN_DIR/work/native/tests.log"
python3 "$SCRIPT_DIR/prepare_software.py"
cd "$DESIGN_DIR/work/software"
"$DESIGN_DIR/work/native/Vintel_8086_chip" --debug DEBUG.COM > native-debug.log 2>&1
cat native-debug.log
test "$(grep -c '^PASS: unchanged Microsoft' native-debug.log)" = 2
EXPECTED=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["accepted"])' "$DESIGN_DIR/work/vector_selection.json")
for mode in min max; do
    if [ "$mode" = max ]; then export I8086_NATIVE_MAX=1; else unset I8086_NATIVE_MAX; fi
    "$DESIGN_DIR/work/native/Vintel_8086_chip" --vectors "$DESIGN_DIR/work/vectors.bin" \
        > "$DESIGN_DIR/work/native/vectors_$mode.log" 2>&1
    cat "$DESIGN_DIR/work/native/vectors_$mode.log"
    grep -Fq "PASS: $EXPECTED physical-chip vectors" "$DESIGN_DIR/work/native/vectors_$mode.log"
done
python3 "$SCRIPT_DIR/check_oracle.py" "$DESIGN_DIR/work/native/Vintel_8086_chip"
