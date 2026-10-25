#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
verilator --lint-only -Wall --top-module mos_6510 "$HERE/../mos_6502/src/mos_6502_native.sv" "$HERE/src/mos_6510_port.sv" "$HERE/src/mos_6510.sv"
echo 'MOS 6510 LINT PASS'
