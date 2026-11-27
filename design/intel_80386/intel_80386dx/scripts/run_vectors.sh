#!/bin/sh
# Replay the pinned SingleStepTests/80386 physical-386EX real-mode captures
# against intel_80386_core.
# Usage: run_vectors.sh [STEM ...]   (no arguments: all 941 files)
# Set SST386_DIR to a local checkout of the pinned revision to avoid the
# download; otherwise files are fetched once into ignored work/sst386/.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
OUT=${I386_VECTOR_DIR:-$DESIGN_DIR/work/vectors}
echo "=== Preparing capture vectors in $OUT ==="
python3 "$SCRIPT_DIR/prepare_vectors.py" "$OUT" "$@"
sh "$SCRIPT_DIR/build_replay.sh"
echo "=== Replaying ==="
set +e
"$DESIGN_DIR/work/verilator/replay" "$OUT/vectors.bin" 1000 > "$OUT/replay.log"
RC=$?
set -e
if [ "$RC" -gt 1 ]; then cat "$OUT/replay.log"; echo "FAIL: replay bench error"; exit 1; fi
tail -1 "$OUT/replay.log"
python3 "$SCRIPT_DIR/summarize_replay.py" "$OUT/vector_manifest.json" "$OUT/replay.log" \
    "$OUT/summary.json" "$SCRIPT_DIR/sst386_open.json"
