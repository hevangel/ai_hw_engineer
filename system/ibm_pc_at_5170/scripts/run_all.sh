#!/bin/sh
# IBM PC AT 5170 regression: lint, BIOS POST boundary with Unicorn replay,
# and synthesis. Usage: scripts/run_all.sh /path/to/atbios.bin
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "$#" -ne 1 ]; then
    echo "usage: $0 /path/to/atbios.bin" >&2
    exit 2
fi
sh "$SCRIPT_DIR/run_post.sh" "$1"
sh "$SCRIPT_DIR/run_synth.sh"
echo "PASS: ibm_pc_at_5170 regression"
