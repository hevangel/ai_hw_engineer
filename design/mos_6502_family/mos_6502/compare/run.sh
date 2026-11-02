#!/bin/sh
set -eu
# Differential check between the functional-bus 6502 and the physical-bus
# cycle core: the same program runs on both, and PC/A/X/Y/SP/P plus memory
# contents are compared at every opcode fetch. Cycles are expected to differ
# (the cycle core models dummy reads); the comparison is architectural.
#
# A three-to-five instruction preamble in each phase normalises the two
# power-up conventions (SP and V) before the comparison starts.
cd "$(dirname "$0")/.."
mkdir -p work
verilator --cc --exe --build -j 4 -Wall --top-module dual_6502_top \
    --Mdir work/dual \
    "$(pwd)/src/mos_6502.sv" "$(pwd)/cycle/src/mos_6502_cycle.sv" \
    "$(pwd)/compare/dual_6502_top.sv" "$(pwd)/compare/dual_test.cpp"
work/dual/Vdual_6502_top | tee work/dual.log
grep -q 'PASS differential Klaus' work/dual.log
