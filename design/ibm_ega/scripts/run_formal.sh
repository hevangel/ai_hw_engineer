#!/bin/sh
# SymbiYosys: unbounded proofs (abc pdr) and covers (smtbmc yices) for the
# graphics controller, the CRT controller and the card top (RAM and ROM
# black-boxed). See plans/formal_plan.md for what is bounded.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${EGA_WORK_DIR:-$ROOT/work}
mkdir -p "$WORK/formal"
echo "== formal"
cd "$ROOT/formal"
for f in ega_graphics_ctrl ega_crtc ibm_ega; do
    start=$(date +%s)
    sby -f --prefix "$WORK/formal/$f" "$f.sby" >"$WORK/formal/$f.log" 2>&1 || {
        tail -40 "$WORK/formal/$f.log"; exit 1; }
    nc=$(grep -c 'reached cover statement' "$WORK/formal/$f.log" || true)
    echo "$f: prove PASS, cover $nc reached ($(( $(date +%s) - start )) s)"
done
echo "PASS: formal prove and cover"
