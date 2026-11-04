#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
MEMBER_SRC="$DESIGN_DIR/src"
EU_SRC="$DESIGN_DIR/../intel_8086/src"
mkdir -p "$DESIGN_DIR/work/lint"
echo '=== Intel 8088 strict RTL lint ==='
verilator --lint-only -Wall --top-module intel_8088_chip \
    "$MEMBER_SRC/intel_8088_biu.sv" "$MEMBER_SRC/intel_8088_chip.sv" \
    "$EU_SRC/intel_8086.sv" "$EU_SRC/intel_8086_alu.sv" \
    "$EU_SRC/intel_8086_muldiv.sv" "$EU_SRC/intel_8086_shift.sv" \
    > "$DESIGN_DIR/work/lint/rtl.log" 2>&1
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_software.sh"
sh "$SCRIPT_DIR/run_native.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== Intel 8088 documented-architecture and native digital-interface verification PASSED ==='
