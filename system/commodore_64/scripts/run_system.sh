#!/bin/sh
# Build and serve the Commodore 64 web front panel on port 8080 (container).
# C64_VARIANT=1 selects the NTSC 6567R8 board.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$SYSTEM/work"
python3 "$SYSTEM/scripts/fetch_firmware.py"
sh "$SYSTEM/scripts/build.sh"
exec python3 "$SYSTEM/host/server.py"
