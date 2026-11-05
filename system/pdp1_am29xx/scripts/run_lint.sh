#!/bin/sh
# Lint the PDP-1 Am29xx system with Verilator's strict warning set.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work"
cd "$ROOT"
# UNOPTFLAT: the Y -> shift -> D path exists in the netlist because the slices
# mux Y between the A latch and F; every shift micro-op selects the A-latch
# destination code, so the path is never combinational at run time. Verilator
# cannot prove the exclusivity across the instance boundary. Simulation and the
# formal shift properties are the evidence that the path settles.
# UNUSEDPARAM: pdp1_defs.svh is included per module (Verilator and Yosys
# disagree about in-module package imports), so each module sees constants it
# does not use.
# PINCONNECTEMPTY: unused Am2901/Am2910 status pins are deliberately
# left open in this board-level model.
verilator --lint-only -Wall \
    -Isystem/pdp1_am29xx/src -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL \
    -Wno-PINCONNECTEMPTY -Wno-UNOPTFLAT -Wno-UNUSEDPARAM \
    --top-module pdp1_am29xx \
    system/pdp1_am29xx/src/microcode/pdp1_uc.sv \
    system/pdp1_am29xx/src/pdp1_memory.sv \
    system/pdp1_am29xx/src/pdp1_io.sv \
    system/pdp1_am29xx/src/pdp1_datapath.sv \
    system/pdp1_am29xx/src/pdp1_microseq.sv \
    system/pdp1_am29xx/src/pdp1_am29xx.sv \
    design/amd_am29xx/amd_am2901/src/amd_am2901.sv \
    design/amd_am29xx/amd_am2901/src/amd_am2901_alu.sv \
    design/amd_am29xx/amd_am2910/src/amd_am2910.sv
echo "lint clean"
