#!/bin/sh
set -eu
D=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$D/work/formal"
cd "$D/formal"
pids=''
for mode in bmc prove cover_stack cover_bus; do
    echo "Intel 8087: controller $mode (explicit numeric abstraction)"
    sby -f -d "$D/work/formal/$mode" intel_8087.sby "$mode" > "$D/work/formal/$mode.log" 2>&1 &
    pids="$pids $!"
done
result=0
for pid in $pids; do
    wait "$pid" || result=1
done
for mode in bmc prove cover_stack cover_bus; do
    if [ "$result" -ne 0 ]; then tail -40 "$D/work/formal/$mode.log"; fi
    tail -3 "$D/work/formal/$mode.log"
done
exit "$result"
