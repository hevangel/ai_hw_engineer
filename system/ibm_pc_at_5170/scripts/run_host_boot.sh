#!/bin/sh
# End-to-end boot through the web/batch simulator (host/simulator.cpp) with
# the AT keyboard model (host/at_keyboard.hpp), diskette adapter, real DMA
# and empty 80287 socket: zero POST errors (no 301, no 601), no F1 stimulus,
# boots the 1.2 MB test diskette and checks screen + written-back image.
#
# Usage: scripts/run_host_boot.sh /path/to/atbios.bin
# Output: $IBM_PC_AT_WORK_DIR (default work)/host_boot/
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${IBM_PC_AT_WORK_DIR:-$SYS_DIR/work}
if [ "$#" -ne 1 ]; then
    echo "usage: $0 /path/to/atbios.bin" >&2
    exit 2
fi
HOST_LINE=$(sh "$SCRIPT_DIR/build_host.sh" "$1" | tail -n 1)
set -- $HOST_LINE
SIM=$2 ROM=$3 VGA=$4
OUT=$WORK_DIR/host_boot
rm -rf "$OUT"
mkdir -p "$OUT"
status=0
json() {
    python3 -c "import json,sys; s=json.load(open(sys.argv[1])); print($1)" "$OUT/run/status.json"
}

echo "== build 1.2 MB test diskette"
python3 "$SCRIPT_DIR/make_test_diskette.py" "$OUT/media"
cp "$OUT/media/boot_1200.img" "$OUT/fda.img"

echo "== run: cold power-on through POST to boot halt (up to 1,000,000,000 clocks)"
start=$(date +%s)
rc=0
"$SIM" "$ROM" "$VGA" "--fda=$OUT/fda.img" --write-back --batch=1000000000 --save-every=50000000 \
    "--out=$OUT/run" "--fst=$OUT/unused.fst" 2> "$OUT/run.log" || rc=$?
echo "wall time $(( $(date +%s) - start )) s; $(tail -n 1 "$OUT/run.log")"
STOP=$(json "s['state']['stopped']")
echo "stopped: $STOP"
if [ "$rc" -ne 3 ] || ! printf '%s\n' "$STOP" | grep -q '^halt at=0000:'; then
    echo "FAIL: expected halt in 0000:xxxx, got rc=$rc stopped='$STOP'" >&2
    status=1
fi
if [ "$(json "s['state']['keyboard']['sentLog'].startswith('AA FA AA')")" != True ]; then
    echo "FAIL: keyboard BAT/reset handshake missing" >&2
    status=1
fi
if [ "$(json "s['state']['dmaWrites'] == 1209344 and s['state']['dmaReads'] == 512 and s['state']['dmaOpen'] == 0 and s['state']['npxAccesses'] >= 2")" != True ]; then
    echo "FAIL: unexpected DMA/80287 counters" >&2
    status=1
fi
echo "== screen"
python3 "$SCRIPT_DIR/check_frame.py" "$VGA" "$OUT/run/frame.ppm" \
    "$SYS_DIR/tb/expected_screen_boot.txt" "$OUT/run/frame.png" || status=1
echo "== written-back image"
python3 - "$OUT/fda.img" "$OUT/media/boot_1200.json" "$OUT/media/boot_1200.img" <<'EOF' || status=1
import json, sys
final = open(sys.argv[1], 'rb').read()
params = json.load(open(sys.argv[2]))
before = open(sys.argv[3], 'rb').read()
lba = params['write_lba']
want = bytes.fromhex(params['write_pattern'])
if final[lba * 512:(lba + 1) * 512] != want:
    raise SystemExit(f'FAIL: sector {lba} of the written-back image is not the pattern')
if final[:lba * 512] != before[:lba * 512] or final[(lba + 1) * 512:] != before[(lba + 1) * 512:]:
    raise SystemExit('FAIL: the written-back image differs outside the written sector')
print(f'PASS: LBA {lba} holds the pattern and no other sector changed')
EOF
[ "$status" -eq 0 ] && echo "PASS: host simulator booted 1.2 MB diskette with AT keyboard (no POST errors)"
exit "$status"
