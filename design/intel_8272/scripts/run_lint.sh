#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for top in intel_8272 intel_8272_codec intel_8272_crc; do
  verilator --lint-only -Wall "$HERE/src/$top.sv"
done
verilator --lint-only --timing -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL -I"$HERE/tb" --top-module tb_top "$HERE/src/intel_8272.sv" "$HERE/tb/intel_8272_if.sv" "$HERE/tb/tb_top.sv"
echo '8272 LINT PASSED'
