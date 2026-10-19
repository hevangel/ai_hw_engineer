#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
python3 scripts/fetch_board_references.py
iverilog -g2012 -DAPPLE_II_CPU_MODULE=apple_ii_rev0_authored -s tb_rev0_full_read -o work/full_read.vvp \
    ../../design/apple_ii_chips/src/*.sv ../../design/apple_ii_chips/src/analog/*.sv \
    ../../design/mos_6502_cycle/src/mos_6502_cycle.sv ../../design/mos_6502_cycle/src/a2_mos6502.sv \
    src/apple_ii_rev0_digital.sv src/apple_ii_rev0_peripherals.sv src/apple_ii_*output.sv \
    src/apple_ii_rev0_authored.sv tb/tb_rev0_full_read.sv
for polarity in 1 -1; do
 for bad in 0 1; do
  log="work/full_read_${polarity}_${bad}.log"
  vvp work/full_read.vvp +POLARITY="$polarity" +BADCHECK="$bad" >"$log" 2>&1 || { cat "$log"; exit 1; }
  cat "$log"
  grep -q 'PASS full physical original Monitor READ' "$log"
  python3 scripts/check_full_read_board.py "$bad"
  cp work/full_read_output.txt "work/full_read_output_${polarity}_${bad}.txt"
 done
done
