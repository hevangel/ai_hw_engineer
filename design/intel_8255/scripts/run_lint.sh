#!/bin/sh
# Run strict RTL, testbench, and authored-source lint.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
RTL="$DESIGN_DIR/src/intel_8255.sv"
TB="$DESIGN_DIR/tb/tb_intel_8255.sv"
FORMAL_PROPS="$DESIGN_DIR/formal/intel_8255_props.sv"
FORMAL_COVER="$DESIGN_DIR/formal/intel_8255_cover.sv"

echo "=== Verilator RTL lint ==="
verilator --lint-only -Wall "$RTL"

echo "=== Verilator RTL + testbench lint ==="
verilator --lint-only -Wall --timing --top-module tb_intel_8255 \
    "$RTL" "$TB"

echo "=== Verible authored-source lint ==="
verible-verilog-lint "$RTL" "$TB" "$FORMAL_PROPS" "$FORMAL_COVER"

echo "=== Lint passed ==="
