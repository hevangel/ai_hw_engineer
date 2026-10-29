#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/scripts/sources.sh"
for region in 0 1; do
    verilator --lint-only -Wall -GREGION=1\'b$region --top-module ricoh_2c02 $RICOH_2C02_SRC
done
echo 'RICOH 2C02 LINT PASS'
