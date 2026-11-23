#!/bin/sh
# Unattended batch run of the IBM PC AT 5170 with the VGA card.
#
# Usage: scripts/run_batch.sh /path/to/atbios.bin CLOCKS OUT_DIR [simulator options]
#   simulator options: --ext-kb=N --script=FILE --save-every=N
# Runs CLOCKS processor clocks headless. Every --save-every clocks (default
# 50,000,000) it writes OUT_DIR/status.json, latest.png and screen.txt and
# adds the frame to OUT_DIR/frames/ when it changed (listed in
# frames.json). Watch it live, or replay the frames afterwards, with
#   scripts/run_web.sh /path/to/atbios.bin 8286 --batch-dir OUT_DIR
# Exit status: 0 when CLOCKS were run, 3 when the machine stopped early
# (status.json says why).
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "$#" -lt 3 ]; then
    echo "usage: $0 /path/to/atbios.bin CLOCKS OUT_DIR [simulator options]" >&2
    exit 2
fi
BIOS=$1 CLOCKS=$2 OUT=$3
shift 3
HOST_LINE=$(sh "$SCRIPT_DIR/build_host.sh" "$BIOS" | tail -n 1)
set -- $HOST_LINE "$@"
shift
SIM=$1 ROM=$2 VGA=$3
shift 3
mkdir -p "$OUT"
echo "== batch: $CLOCKS clocks into $OUT"
exec "$SIM" "$ROM" "$VGA" "--batch=$CLOCKS" "--out=$OUT" "--fst=$OUT/capture.fst" "$@"
