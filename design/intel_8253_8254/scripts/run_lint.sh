#!/bin/sh
# Run strict lint for both variants and all authored SystemVerilog sources.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
RTL="$DESIGN_DIR/src/intel_8253_8254.sv"
TB="$DESIGN_DIR/tb/tb_top.sv"

echo "=== Verilator Intel 8253 RTL lint ==="
verilator --lint-only -Wall --top-module intel_8253_8254 \
    -GIS_8254=0 "$RTL"

echo "=== Verilator Intel 8254 RTL lint ==="
verilator --lint-only -Wall --top-module intel_8253_8254 \
    -GIS_8254=1 "$RTL"

echo "=== Verilator dual-variant testbench lint ==="
verilator --lint-only -Wall --timing --top-module tb_top "$RTL" "$TB"

echo "=== Verible authored-source lint ==="
verible-verilog-lint "$RTL" "$TB" "$DESIGN_DIR"/formal/*.sv

echo "=== Lint passed ==="
