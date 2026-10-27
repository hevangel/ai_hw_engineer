#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/formal"
cd "$HERE/formal"
for task in bmc prove cover; do
    sby -f -d "$HERE/work/formal/ricoh_2c02_$task" ricoh_2c02.sby "$task"
done
echo 'RICOH 2C02 FORMAL PASS'
