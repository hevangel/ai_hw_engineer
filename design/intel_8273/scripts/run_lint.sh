#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
verilator --lint-only -Wall --top-module intel_8273 "$HERE"/src/*.sv
for top in tb_top tb_dpll tb_dma_link tb_long_frame; do
  if [ "$top" = tb_dma_link ]; then
    verilator --lint-only --timing -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL --top-module "$top" "$HERE"/src/*.sv "$ROOT/design/intel_8237/src/intel_8237.sv" "$HERE/tb/$top.sv"
  else
    verilator --lint-only --timing -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL -I"$HERE/tb" --top-module "$top" "$HERE"/src/*.sv "$HERE/tb/intel_8273_if.sv" "$HERE/tb/$top.sv"
  fi
done
echo '8273 LINT PASSED'
