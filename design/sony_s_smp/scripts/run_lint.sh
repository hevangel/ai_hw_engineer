#!/bin/sh
# Strict Verilator lint of the SONY S-SMP RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
verilator --lint-only -Wall  --top-module sony_s_smp "$HERE/src/sony_s_smp.sv" "$D/sony_spc700/src/sony_spc700.sv"
echo 'SONY S-SMP LINT PASS'
