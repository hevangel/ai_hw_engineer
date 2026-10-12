#!/bin/sh
set -eu
unset I8086_VECTOR_PREFIX
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
python3 "$SCRIPT_DIR/prepare_vectors.py"
sh "$SCRIPT_DIR/build_runner.sh"
"$DESIGN_DIR/work/verilator/Vintel_8086" --vectors "$DESIGN_DIR/work/vectors.bin" \
    > "$DESIGN_DIR/work/vectors.log" 2>&1
cat "$DESIGN_DIR/work/vectors.log"
EXPECTED=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["accepted"])' "$DESIGN_DIR/work/vector_selection.json")
grep -Fq "PASS: $EXPECTED physical-chip vectors" "$DESIGN_DIR/work/vectors.log"
python3 "$SCRIPT_DIR/check_oracle.py"
python3 "$SCRIPT_DIR/update_coverage.py"
