#!/bin/sh
set -eu
unset I8088_VECTOR_PREFIX
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/native"
sh "$SCRIPT_DIR/build_runner.sh"
"$DESIGN_DIR/work/verilator/Vintel_8088_chip" > "$DESIGN_DIR/work/native/tests.log" 2>&1
cat "$DESIGN_DIR/work/native/tests.log"
grep -q '^PASS: .* native minimum/maximum-mode' "$DESIGN_DIR/work/native/tests.log"
python3 "$SCRIPT_DIR/prepare_vectors.py"
EXPECTED=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["accepted"])' "$DESIGN_DIR/work/vector_selection.json")
for mode in min max; do
    if [ "$mode" = max ]; then export I8088_NATIVE_MAX=1; else unset I8088_NATIVE_MAX; fi
    "$DESIGN_DIR/work/verilator/Vintel_8088_chip" --vectors "$DESIGN_DIR/work/vectors.bin" \
        > "$DESIGN_DIR/work/native/vectors_$mode.log" 2>&1
    cat "$DESIGN_DIR/work/native/vectors_$mode.log"
    grep -Fq "PASS: $EXPECTED physical-chip vectors" "$DESIGN_DIR/work/native/vectors_$mode.log"
done
python3 "$SCRIPT_DIR/check_oracle.py" "$DESIGN_DIR/work/verilator/Vintel_8088_chip"
