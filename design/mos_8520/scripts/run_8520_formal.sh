#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
cd "$HERE/formal"
for task in bmc prove cover; do
    sby -f -d "$HERE/work/tod_$task" mos_8520_tod.sby "$task"
done
