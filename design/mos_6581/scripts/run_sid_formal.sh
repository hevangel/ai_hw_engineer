#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
cd "$HERE/formal"
for model in m6581 m8580; do
    for task in bmc prove cover; do
        sby -f -d "$HERE/work/sid_${model}_$task" mos_6581.sby "${model}_$task"
    done
done
