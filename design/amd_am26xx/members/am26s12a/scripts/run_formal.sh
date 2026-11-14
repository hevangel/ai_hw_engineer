#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
TASK=${1:-all}
case "$TASK" in
    all) MODES="bmc prove cover" ;;
    bmc|prove|cover) MODES=$TASK ;;
    *) echo "ERROR: expected all, bmc, prove or cover" >&2; exit 2 ;;
esac
mkdir -p "$DESIGN_DIR/work/formal"
cd "$DESIGN_DIR/formal"
for mode in $MODES; do
    echo "=== Am26S12A formal: $mode ==="
    sby -f -d "$DESIGN_DIR/work/formal/$mode" am26s12a.sby "$mode"
done
echo "Am26S12A FORMAL PASSED"
