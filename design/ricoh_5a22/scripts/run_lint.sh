#!/bin/sh
# Strict Verilator lint of the RICOH 5A22 RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
verilator --lint-only -Wall  --top-module ricoh_5a22 "$HERE/src/ricoh_5a22.sv" "$D/wdc_65c816/src/wdc_65c816.sv"
echo 'RICOH 5A22 LINT PASS'
