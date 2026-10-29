#!/bin/sh
# Strict Verilator lint of the SONY SPC700 RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
verilator --lint-only -Wall  --top-module sony_spc700 "$HERE/src/sony_spc700.sv"
echo 'SONY SPC700 LINT PASS'
