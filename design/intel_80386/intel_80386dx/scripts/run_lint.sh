#!/bin/sh
# Verilator -Wall lint of the core and its submodules.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC=$(dirname "$SCRIPT_DIR")/src
verilator --lint-only -Wall --top-module intel_80386_core \
  "$SRC/intel_80386_pkg.sv" "$SRC/intel_80386_decode.sv" \
  "$SRC/intel_80386_divider.sv" "$SRC/intel_80386_core.sv"
echo "PASS: verilator -Wall lint"
