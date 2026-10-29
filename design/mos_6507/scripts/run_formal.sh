#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/formal"
cd "$HERE/formal"
for task in bmc prove cover; do
    sby -f -d "$HERE/work/formal/$task" mos_6507.sby "$task"
done
