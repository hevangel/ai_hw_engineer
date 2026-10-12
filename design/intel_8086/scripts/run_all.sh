#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/lint"
echo '=== Intel 8086 strict RTL lint ==='
verilator --lint-only -Wall --top-module intel_8086_chip \
    "$DESIGN_DIR/src/"*.sv \
    > "$DESIGN_DIR/work/lint/rtl.log" 2>&1
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_vectors.sh"
"$DESIGN_DIR/work/verilator/Vintel_8086" --control unused
sh "$SCRIPT_DIR/run_software.sh"
sh "$SCRIPT_DIR/run_native.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== Intel 8086 documented-architecture and native digital-interface verification PASSED ==='
