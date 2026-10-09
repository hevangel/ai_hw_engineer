#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/lint"
echo '=== Intel 8086 milestone 1 strict RTL lint ==='
verilator --lint-only -Wall --top-module intel_8086 \
    "$DESIGN_DIR/src/intel_8086_alu.sv" "$DESIGN_DIR/src/intel_8086.sv" \
    > "$DESIGN_DIR/work/lint/rtl.log" 2>&1
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_vectors.sh"
sh "$SCRIPT_DIR/run_software.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== Intel 8086 milestone 1 verification PASSED (incomplete CPU; see report) ==='
