#!/bin/sh
# Yosys synthesis check for the PDP-8 CPU, console and front panel.
# The 4K core memory is an external interface (stub), matching the system
# synthesis-boundary convention used elsewhere in this repository.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work/synth"
yosys -Q -l "$SYSTEM/work/synth/pdp8_am29xx.log" -p "read_verilog -sv \
    $ROOT/design/amd_am29xx/amd_am2901/src/amd_am2901_alu.sv \
    $ROOT/design/amd_am29xx/amd_am2901/src/amd_am2901.sv \
    $ROOT/design/amd_am29xx/amd_am2910/src/amd_am2910.sv \
    $SYSTEM/src/pdp8_sequencer.sv \
    $SYSTEM/src/pdp8_ucode.sv \
    $SYSTEM/src/pdp8_cpu.sv \
    $SYSTEM/src/pdp8_console.sv \
    $SYSTEM/src/pdp8_panel.sv \
    $SYSTEM/src/pdp8_top.sv; \
    read_verilog -lib -sv $SYSTEM/synth/pdp8_core_stub.v; \
    hierarchy -check -top pdp8_top; synth -noabc -top pdp8_top; \
    abc -script +strash,map; check -assert; stat"
echo "Synthesis OK (log: $SYSTEM/work/synth/pdp8_am29xx.log)"
