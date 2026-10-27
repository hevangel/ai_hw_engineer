#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/formal"
cd "$HERE/formal"
for task in bmc prove cover; do
    sby -f -d "$HERE/work/formal/ricoh_2a03_$task" ricoh_2a03.sby "$task"
done
echo 'RICOH 2A03 FORMAL PASS'
