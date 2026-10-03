#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/formal"
cd "$HERE/formal"
if [ "${1:-all}" = all ]; then
  for task in bmc prove cover_read cover_write cover_seek cover_nd; do sby -f -d "$HERE/work/formal/$task" intel_8272.sby "$task"; done
elif [ "$1" = cover ]; then
  for task in cover_read cover_write cover_seek cover_nd; do sby -f -d "$HERE/work/formal/$task" intel_8272.sby "$task"; done
else
  sby -f -d "$HERE/work/formal/$1" intel_8272.sby "$1"
fi
echo '8272 FORMAL PASSED'
