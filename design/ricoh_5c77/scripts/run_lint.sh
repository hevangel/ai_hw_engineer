#!/bin/sh
# Strict Verilator lint of the RICOH 5C77 RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
verilator --lint-only -Wall  --top-module ricoh_5c77 "$HERE/src/ricoh_5c77.sv"
echo 'RICOH 5C77 LINT PASS'
