#!/bin/sh
# Yosys generic synthesis of the UPI-42 core (program ROM is a port).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${INTEL_8042_WORK_DIR:-$ROOT/work}
mkdir -p "$WORK"
echo "== synthesis: upi42_core"
yosys -q -l "$WORK/synth.log" -p "
read_verilog -sv $ROOT/src/upi42_core.sv
synth -top upi42_core
check -assert
tee -o $WORK/synth_stat.txt stat
" >/dev/null
grep -E 'Number of cells|cells$' "$WORK/synth_stat.txt" | head -3
if grep -q '^Latch inferred' "$WORK/synth.log"; then echo "FAIL: latch inferred"; exit 1; fi
echo "PASS: upi42_core synthesis"
