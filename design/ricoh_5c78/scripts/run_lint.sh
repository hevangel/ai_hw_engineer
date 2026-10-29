#!/bin/sh
# Strict Verilator lint of the RICOH 5C78 RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
verilator --lint-only -Wall  --top-module ricoh_5c78 "$HERE/src/ricoh_5c78.sv"
echo 'RICOH 5C78 LINT PASS'
