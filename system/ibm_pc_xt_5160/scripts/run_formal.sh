#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$SYSTEM/work/formal"
cd "$SYSTEM/formal"
for mode in bmc prove cover; do
    sby -f -d "$SYSTEM/work/formal/$mode" xt_fixed_disk.sby "$mode" > "$SYSTEM/work/formal/$mode.log" 2>&1 || {
        tail -40 "$SYSTEM/work/formal/$mode.log";exit 1;
    }
    tail -3 "$SYSTEM/work/formal/$mode.log"
done
