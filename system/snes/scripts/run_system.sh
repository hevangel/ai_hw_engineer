#!/bin/sh
# Build and serve the SNES web panel on port 8080 (container).
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work"
python3 "$SYSTEM/scripts/fetch_roms.py"
python3 "$ROOT/design/sony_s_smp/scripts/fetch_ipl.py"
sh "$SYSTEM/scripts/build.sh"
exec python3 "$SYSTEM/host/server.py"
