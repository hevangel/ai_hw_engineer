#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
verilator --lint-only -Wall --top-module intel_8008 "$ROOT/src/intel_8008.sv"
echo "Intel 8008 strict lint passed"
