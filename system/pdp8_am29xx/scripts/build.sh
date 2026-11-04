#!/bin/sh
# Build the PDP-8 system models: architecture testbench, panel testbench and
# the persistent host simulator used by the web front panel.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work"

SOURCES="$ROOT/design/amd_am29xx/amd_am2901/src/amd_am2901.sv \
$ROOT/design/amd_am29xx/amd_am2901/src/amd_am2901_alu.sv \
$ROOT/design/amd_am29xx/amd_am2910/src/amd_am2910.sv \
$SYSTEM/src/pdp8_sequencer.sv \
$SYSTEM/src/pdp8_ucode.sv \
$SYSTEM/src/pdp8_cpu.sv \
$SYSTEM/src/pdp8_core.sv \
$SYSTEM/src/pdp8_console.sv \
$SYSTEM/src/pdp8_panel.sv \
$SYSTEM/src/pdp8_top.sv"

echo "== Lint"
# The Am2901 model reports the documented transparent-latch structure as
# UNOPTFLAT; the design's own formal harness covers that path.
verilator --lint-only -Wall -Wno-UNOPTFLAT -Wno-DECLFILENAME -Wno-fatal --top-module pdp8_top \
    $SOURCES

echo "== Architecture testbench"
verilator --binary --timing -Wall -Wno-UNOPTFLAT -Wno-fatal --top-module tb_top \
    --Mdir "$SYSTEM/work/obj_tb_top" $SOURCES "$SYSTEM/tb/tb_top.sv" \
    > "$SYSTEM/work/build_top.log" 2>&1

echo "== Panel/interrupt testbench"
verilator --binary --timing -Wall -Wno-UNOPTFLAT -Wno-fatal --top-module tb_panel \
    --Mdir "$SYSTEM/work/obj_tb_panel" $SOURCES "$SYSTEM/tb/tb_panel.sv" \
    > "$SYSTEM/work/build_panel.log" 2>&1

echo "== Host simulator"
verilator --cc --exe --build -j 2 -Wall -Wno-UNOPTFLAT -Wno-fatal --top-module pdp8_top \
    --Mdir "$SYSTEM/work/obj_host" $SOURCES "$SYSTEM/host/simulator.cpp" \
    > "$SYSTEM/work/build_host.log" 2>&1

echo "PASS: models built"
