#!/bin/sh
set -eu
D=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
X=$(CDPATH= cd -- "$D/../../intel_8087/src" && pwd)
echo 'Intel 80387: strict lint of the shared x87 controller (VARIANT=2)'
verilator --lint-only -Wall -GVARIANT=2 -GAW=32 -I"$X" --top-module intel_8087 \
  "$X/intel_8087_alu.sv" "$X/intel_8087_trans.sv" "$X/intel_8087.sv"
echo 'PASS lint'
