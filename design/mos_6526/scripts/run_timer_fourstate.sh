#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REF="$HERE/work/reference"
OUT="$HERE/work/timer-reference"
mkdir -p "$OUT"
python3 "$HERE/scripts/fetch_timer_reference.py"
gcc -O2 -I"$REF" -I"$HERE/tb/vice_stubs" "$REF/ciatimer.c" \
    "$HERE/tb/vice_timer_adapter.c" "$HERE/tb/timer_trace_generator.c" -o "$OUT/generate"
"$OUT/generate" > "$HERE/work/timer-vectors.txt"
# Stream records from the container filesystem: character-oriented simulator
# file I/O over a Windows bind mount is disproportionately expensive.
VECTORS=$(mktemp /tmp/mos6526-timer.XXXXXX)
trap 'rm -f "$VECTORS"' 0
cp "$HERE/work/timer-vectors.txt" "$VECTORS"
xezim --simulate --sv2017 --error-exit -s tb_timer_trace "$HERE/src/mos_6526_timer.sv" \
    "$HERE/tb/tb_timer_trace.sv" +vectors="$VECTORS" \
    --max-time 1000000ns -l "$HERE/work/timer-fourstate.log"
grep 'MOS 6526 FOUR-STATE TIMER PASS:' "$HERE/work/timer-fourstate.log"
