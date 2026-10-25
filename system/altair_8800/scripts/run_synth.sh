#!/bin/sh
# Yosys synthesis check for the Altair 8800 board logic and its 8080 core.
# The altair_ram storage model is an external interface (blackbox), matching
# the ibm_pc system's synthesizable-boundary convention.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work/synth"
yosys -Q -l "$SYSTEM/work/synth/altair_8800.log" -p "read_verilog -sv \
    $ROOT/design/intel_8080/src/intel_8080_alu.sv \
    $ROOT/design/intel_8080/src/intel_8080.sv \
    $SYSTEM/src/altair_8800.sv; \
    read_verilog -lib -sv $SYSTEM/synth/altair_ram_stub.v; \
    hierarchy -check -top altair_8800; synth -noabc -top altair_8800; \
    abc -script +strash,map; check -assert; stat"
echo "Synthesis OK (log: $SYSTEM/work/synth/altair_8800.log)"
