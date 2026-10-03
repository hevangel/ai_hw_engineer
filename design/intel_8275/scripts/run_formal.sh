#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/formal"
cd "$HERE/formal"
if [ "${1:-all}" = all ]; then
  for task in bmc prove cover; do sby -f -d "$HERE/work/formal/$task" intel_8275.sby "$task"; done
else
  sby -f -d "$HERE/work/formal/$1" intel_8275.sby "$1"
fi
echo '8275 FORMAL PASSED'
