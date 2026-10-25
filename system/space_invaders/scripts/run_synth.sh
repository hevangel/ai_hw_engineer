#!/bin/sh
# Yosys synthesis check for the Space Invaders board logic and its 8080
# core. The si_memory storage model is an external interface (blackbox).
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work/synth"
yosys -Q -l "$SYSTEM/work/synth/space_invaders.log" -p "read_verilog -sv \
    $ROOT/design/intel_8080/src/intel_8080_alu.sv \
    $ROOT/design/intel_8080/src/intel_8080.sv \
    $SYSTEM/src/space_invaders.sv \
    $SYSTEM/src/si_shift.sv; \
    read_verilog -lib -sv $SYSTEM/synth/si_memory_stub.v; \
    hierarchy -check -top space_invaders; synth -noabc -top space_invaders; \
    abc -script +strash,map; check -assert; stat"
echo "Synthesis OK (log: $SYSTEM/work/synth/space_invaders.log)"
