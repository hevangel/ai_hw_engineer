#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/scripts/sources.sh"
for region in 0 1; do
    verilator --lint-only -Wall -GREGION=1\'b$region --top-module ricoh_2a03 $RICOH_2A03_SRC
done
echo 'RICOH 2A03 LINT PASS'
