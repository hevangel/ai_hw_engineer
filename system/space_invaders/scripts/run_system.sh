#!/bin/sh
# Build and serve the Space Invaders web cabinet on port 8080 (container).
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$SYSTEM/work"
python3 "$SYSTEM/scripts/fetch_roms.py"
sh "$SYSTEM/scripts/build.sh"
exec python3 "$SYSTEM/host/server.py"
