#!/bin/sh
# Yosys synthesis check for the PDP-1 Am29xx machine.
# The core array is replaced by synth/pdp1_memory_stub.sv (see the report).
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work"
cd "$ROOT"
yosys -p "
  read_verilog -sv -I system/pdp1_am29xx/src \
    system/pdp1_am29xx/src/microcode/pdp1_uc.sv \
    system/pdp1_am29xx/synth/pdp1_memory_stub.sv \
    system/pdp1_am29xx/src/pdp1_io.sv \
    system/pdp1_am29xx/src/pdp1_datapath.sv \
    system/pdp1_am29xx/src/pdp1_microseq.sv \
    system/pdp1_am29xx/src/pdp1_am29xx.sv \
    design/amd_am29xx/amd_am2901/src/amd_am2901.sv \
    design/amd_am29xx/amd_am2901/src/amd_am2901_alu.sv \
    design/amd_am29xx/amd_am2910/src/amd_am2910.sv
  hierarchy -top pdp1_am29xx
  proc; opt; memory_collect; opt
  synth -top pdp1_am29xx
  check
  stat
" 2>&1 | tee "$SYSTEM/work/synth.log"
echo "synthesis complete"
