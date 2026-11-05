#!/bin/sh
# Build the model, assemble the panel demo and serve the front panel.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
cd "$ROOT"
mkdir -p "$SYSTEM/work"
if [ ! -x "$SYSTEM/work/obj/Vpdp1_am29xx" ]; then
  sh "$SYSTEM/scripts/build_sim.sh"
fi
python3 "$SYSTEM/scripts/pdp1asm.py" "$SYSTEM/tests/demo.pdp1" \
    --hex "$SYSTEM/work/demo.hex" --listing "$SYSTEM/work/demo.lst"
exec python3 "$SYSTEM/host/server.py"
