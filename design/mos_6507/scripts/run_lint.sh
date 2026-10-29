#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
verilator --lint-only -Wall --top-module mos_6507 "$HERE/../mos_6502_family/mos_6502/src/mos_6502_native.sv" "$HERE/src/mos_6507.sv"
echo 'MOS 6507 LINT PASS'
