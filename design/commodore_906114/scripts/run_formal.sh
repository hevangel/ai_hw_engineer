#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/formal"
cd "$HERE/formal"
for task in bmc cover; do
    "${SBY:-sby}" -f -d "$HERE/work/formal/$task" commodore_906114.sby "$task"
done
echo 'COMMODORE 906114 FORMAL PASS'
