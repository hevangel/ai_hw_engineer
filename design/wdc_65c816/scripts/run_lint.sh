#!/bin/sh
# Strict Verilator lint of the WDC 65C816 RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
verilator --lint-only -Wall  --top-module wdc_65c816 "$HERE/src/wdc_65c816.sv"
echo 'WDC 65C816 LINT PASS'
