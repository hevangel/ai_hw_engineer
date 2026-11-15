#!/bin/sh
# Strict Verilator lint of the 8042 RTL.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
echo "== lint"
verilator --lint-only -Wall --top-module intel_8042 \
    "$ROOT/src/upi42_core.sv" "$ROOT/src/intel_8042.sv"
echo "PASS: lint"
