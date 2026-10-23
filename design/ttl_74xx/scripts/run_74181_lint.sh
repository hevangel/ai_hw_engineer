#!/bin/sh
# Run strict RTL, formal, and testbench lint inside ai-hw-engineer:latest.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
UVM_HOME=${UVM_HOME_2017:-/opt/uvm/1800.2-2017}

echo "=== Verilator RTL lint ==="
verilator --lint-only -Wall "$DESIGN_DIR/src/alu_74181.sv"

echo "=== Verilator exhaustive-testbench lint ==="
verilator --lint-only -Wall --timing --top-module tb_exhaustive \
    "$DESIGN_DIR/src/alu_74181.sv" \
    "$DESIGN_DIR/tb/tb_exhaustive.sv"

echo "=== Verible authored-source lint ==="
verible-verilog-lint \
    "$DESIGN_DIR/src/alu_74181.sv" \
    "$DESIGN_DIR/formal/alu_74181_props.sv" \
    "$DESIGN_DIR/tb/alu_74181_if.sv" \
    "$DESIGN_DIR/tb/tb_exhaustive.sv" \
    "$DESIGN_DIR/tb/tb_top.sv"

# Verible resolves quoted includes relative to its current directory. Run the
# package check from the UVM source directory so uvm_macros.svh is available.
(
    cd "$UVM_HOME/src"
    verible-verilog-lint "$DESIGN_DIR/tb/alu_74181_uvm_pkg.sv"
)

echo "=== Lint passed ==="
