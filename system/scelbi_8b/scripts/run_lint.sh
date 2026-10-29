#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
verilator --lint-only -Wall --top-module scelbi_8b \
  "$ROOT/design/intel_8008/src/intel_8008.sv" "$SYSTEM/src/scelbi_8b.sv"
echo "SCELBI 8B strict lint passed"
