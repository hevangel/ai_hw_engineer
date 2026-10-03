#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
verilator --lint-only -Wall "$HERE/src/intel_8275.sv"
verilator --lint-only --timing -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL --top-module tb_top "$HERE/src/intel_8275.sv" "$HERE/tb/tb_top.sv"
echo '8275 LINT PASSED'
