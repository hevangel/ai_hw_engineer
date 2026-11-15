#!/bin/sh
# Strict Verilator lint of the MC146818 RTL (no waivers).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
echo "== lint"
verilator --lint-only -Wall --top-module motorola_mc146818 "$ROOT/src/motorola_mc146818.sv"
verilator --lint-only -Wall --top-module motorola_mc146818 -GFAST_SHIFT=6 "$ROOT/src/motorola_mc146818.sv"
echo "PASS: lint"
