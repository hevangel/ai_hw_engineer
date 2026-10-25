#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
verilator --lint-only -Wall "$HERE/src/mos_6522.sv"
verilator --lint-only -Wall --timing -Wno-TIMESCALEMOD --top-module tb_top \
    "$HERE/src/mos_6522.sv" "$HERE/tb/tb_top.sv"
