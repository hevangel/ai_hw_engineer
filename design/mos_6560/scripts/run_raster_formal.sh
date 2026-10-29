#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work"
cd "$HERE/formal"
for profile in pal ntsc; do
    for task in bmc prove cover; do
        sby -f -d "$HERE/work/raster_${profile}_$task" mos_6560_raster.sby "${profile}_$task"
    done
done
