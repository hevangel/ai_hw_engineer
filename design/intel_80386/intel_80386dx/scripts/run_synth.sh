#!/bin/sh
# Generic Yosys synthesis of intel_80386_core and its submodules.
# Set I386_YOSYS to choose the Yosys binary (default: yosys).
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=$DESIGN_DIR/work/synth
YOSYS=${I386_YOSYS:-yosys}
SRC="$DESIGN_DIR/src/intel_80386_pkg.sv $DESIGN_DIR/src/intel_80386_decode.sv $DESIGN_DIR/src/intel_80386_divider.sv $DESIGN_DIR/src/intel_80386_core.sv"
mkdir -p "$WORK_DIR"
for top in intel_80386_divider intel_80386_decode intel_80386_core; do
    echo "=== Synthesizing $top ==="
    # The SAT-based share pass exhausts memory on the core; -noshare skips it.
    "$YOSYS" -Q -q -l "$WORK_DIR/$top.log" -p "read_verilog -sv $SRC; hierarchy -check -top $top; synth -noshare -top $top; check -assert; stat" >/dev/null
    grep -E "cells$|Number of cells" "$WORK_DIR/$top.log" | tail -1
done
echo "=== Synthesis complete ==="
