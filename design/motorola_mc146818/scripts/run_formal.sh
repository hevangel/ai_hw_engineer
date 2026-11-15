#!/bin/sh
# SymbiYosys: unbounded proof (abc pdr) and cover (smtbmc yices).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${MC146818_WORK_DIR:-$ROOT/work}
mkdir -p "$WORK/formal"
echo "== formal"
cd "$ROOT/formal"
sby -f --prefix "$WORK/formal/mc146818" motorola_mc146818.sby >"$WORK/formal/sby.log" 2>&1 || {
    tail -40 "$WORK/formal/sby.log"; exit 1; }
grep -E 'DONE \(|summary' "$WORK/formal/sby.log" | head -20
echo "PASS: formal prove and cover"
