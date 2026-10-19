#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/formal"
cd "$HERE/formal"
for design in mos_6510_port mos_6510; do
    for task in bmc prove cover; do
        sby -f -d "$HERE/work/formal/${design}_$task" "$design.sby" "$task"
    done
done
