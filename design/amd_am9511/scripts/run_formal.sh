#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
python3 "$SCRIPT_DIR/generate_formal_stack.py" --check
mkdir -p "$DESIGN_DIR/work/formal"
cd "$DESIGN_DIR/formal"
for unit in amd_am9511_fixed amd_am9511; do
 for mode in bmc prove cover; do
  echo "Formal $unit $mode"
  sby -f -d "$DESIGN_DIR/work/formal/${unit}_${mode}" "${unit}.sby" "$mode"
 done
done
