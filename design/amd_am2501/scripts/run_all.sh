#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/lint"
echo "=== Am2501 Verilator lint ==="
for enables in 6 2; do
    verilator --lint-only -Wall --top-module amd_am2501 -GCE_INPUTS="$enables" \
        "$DESIGN_DIR/src/amd_am2501.sv" > "$DESIGN_DIR/work/lint/rtl_$enables.log" 2>&1
done
verilator --lint-only -Wall --timing --top-module tb_top \
    "$DESIGN_DIR/src/amd_am2501.sv" "$DESIGN_DIR/tb/tb_top.sv" \
    > "$DESIGN_DIR/work/lint/tb.log" 2>&1
sh "$SCRIPT_DIR/run_formal.sh" all
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_synth.sh"
echo "=== Am2501 complete verification PASSED ==="
