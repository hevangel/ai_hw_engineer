#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
verilator --lint-only -Wall --top-module micral_n \
  "$ROOT/design/intel_8008/src/intel_8008.sv" "$SYSTEM/src/micral_n.sv"
sh "$SYSTEM/scripts/run_sim.sh"
python3 "$SYSTEM/scripts/test_backend.py"
