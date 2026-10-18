#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$SYSTEM/work/formal"
cd "$SYSTEM/formal"
for task in bmc prove cover; do
    sby -f -d "$SYSTEM/work/formal/bus_$task" model30_bus.sby "$task"
done
for task in bmc cover; do
    sby -f -d "$SYSTEM/work/formal/fixed_disk_$task" model30_fixed_disk.sby "$task"
done
echo 'PASS: Model 30 bus bridge safety and non-vacuity (native CPU protocol tested separately)'
