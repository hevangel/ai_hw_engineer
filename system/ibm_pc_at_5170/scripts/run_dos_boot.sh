#!/bin/sh
# Boot IBM PC DOS 3.00 (360 KB Disk 1 in the 1.2 MB drive A) on the VGA
# machine through the web/batch simulator (host/simulator.cpp), answer Date
# and Time, run DIR, write TEST.TXT, warm-reboot with Ctrl+Alt+Del, answer
# Date and Time again, and read TEST.TXT back from the written diskette.
#
# Usage: scripts/run_dos_boot.sh /path/to/atbios.bin
# Output: $IBM_PC_AT_WORK_DIR (default work)/dos_boot/
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
DOS_IMG=$(python3 "$SCRIPT_DIR/get_dos.py")
OUT=$WORK_DIR/dos_boot
rm -rf "$OUT"
mkdir -p "$OUT"
cp "$DOS_IMG" "$OUT/fda.img"
status=0
json() {
    python3 -c "import json,sys; s=json.load(open(sys.argv[1])); print($1)" "$OUT/run/status.json"
}

cat > "$OUT/dos.script" <<'EOF'
when "Enter new date" Enter
when "Enter new time" Enter
when "A>" "dir\n"
wait 50000000
when "A>" "echo HELLO>TEST.TXT\n"
wait 50000000
when "A>" Ctrl+Alt+Del
when "Enter new date" Enter
when "Enter new time" Enter
when "A>" "type TEST.TXT\n"
wait 30000000
EOF

echo "== run: PC DOS 3.00 boot, DIR, write TEST.TXT, Ctrl+Alt+Del, readback"
start=$(date +%s)
rc=0
"$SIM" "$ROM" "$VGA" "--fda=$OUT/fda.img" --write-back --batch=1500000000 \
    --save-every=20000000 --until-script "--script=$OUT/dos.script" \
    "--out=$OUT/run" "--fst=$OUT/unused.fst" 2> "$OUT/run.log" || rc=$?
echo "wall time $(( $(date +%s) - start )) s; $(tail -n 1 "$OUT/run.log")"
if [ "$rc" -ne 0 ]; then
    echo "FAIL: simulator exited with rc=$rc stopped='$(json "s['state']['stopped']")'" >&2
    status=1
fi
echo "resets=$(json "s['state']['cpuResets']") dmaWrites=$(json "s['state']['dmaWrites']") dmaReads=$(json "s['state']['dmaReads']") dmaOpen=$(json "s['state']['dmaOpen']")"
if [ "$(json "s['state']['cpuResets'] >= 4 and s['state']['dmaOpen'] == 0")" != True ]; then
    echo "FAIL: expected warm-reboot reset count >= 4 and dmaOpen == 0" >&2
    status=1
fi
echo "== screen at readback"
sed 's/^/  | /' "$OUT/run/screen.txt" | grep -v '^  | $' || true
if ! grep -q "Version 3.00" "$OUT/run/screen.txt" || ! grep -q "^HELLO$" "$OUT/run/screen.txt"; then
    echo "FAIL: expected PC DOS 3.00 banner and HELLO readback on final screen" >&2
    status=1
fi
echo "== check written-back FAT12 image"
python3 - "$OUT/fda.img" <<'EOF' || status=1
import pathlib, struct, sys
d = pathlib.Path(sys.argv[1]).read_bytes()
ents = [d[5 * 512 + i * 32:5 * 512 + (i + 1) * 32] for i in range(112)]
matches = [e for e in ents if e[:11] == b'TEST    TXT']
if len(matches) != 1:
    raise SystemExit(f'FAIL: expected 1 TEST.TXT entry, got {len(matches)}')
clus, sz = struct.unpack('<HI', matches[0][26:32])
off = (1 + 2 + 2 + 7 + (clus - 2) * 2) * 512
payload = d[off:off + sz]
if payload != b'HELLO\r\n':
    raise SystemExit(f'FAIL: expected b"HELLO\\r\\n" in TEST.TXT, got {payload!r}')
print(f'PASS: TEST.TXT cluster={clus} size={sz} payload={payload!r}')
EOF
[ "$status" -eq 0 ] && echo "PASS: PC DOS 3.00 booted, ran DIR, wrote TEST.TXT, warm-rebooted, and read TEST.TXT back"
exit "$status"
