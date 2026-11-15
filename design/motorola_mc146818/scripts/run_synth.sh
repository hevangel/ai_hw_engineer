#!/bin/sh
# Yosys generic synthesis of the MC146818 (real-time divider, no image).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${MC146818_WORK_DIR:-$ROOT/work}
mkdir -p "$WORK"
echo "== synthesis: motorola_mc146818"
yosys -q -l "$WORK/synth.log" -p "
read_verilog -sv $ROOT/src/motorola_mc146818.sv
synth -top motorola_mc146818
check -assert
tee -o $WORK/synth_stat.txt stat
" >/dev/null
grep -E 'cells$|Number of cells|DFF|dff' "$WORK/synth_stat.txt" | head -12
if grep -q '^Latch inferred' "$WORK/synth.log"; then echo "FAIL: latch inferred"; exit 1; fi
echo "PASS: synthesis (check -assert clean, no latches)"
