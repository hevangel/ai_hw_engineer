#!/bin/sh
# Strict Verilator lint of the SONY S-DSP RTL.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
D=$(dirname "$HERE")
verilator --lint-only -Wall -I"$HERE/src" --top-module sony_s_dsp "$HERE/src/sony_s_dsp.sv"
echo 'SONY S-DSP LINT PASS'
