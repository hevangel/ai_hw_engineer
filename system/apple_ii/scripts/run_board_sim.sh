#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/generate_rev0.py --check
mkdir -p work
# Icarus is the board simulator. Xezim cannot run this resolved bus: it loses
# driven CPU data (see report/final_report.md, item 6). That defect is kept
# reproducible by scripts/run_xezim_board_probe.sh, which is a tool probe and
# not a board option.
iverilog -g2012 -s tb_rev0_wiring -o work/board.vvp \
    ../../design/apple_ii_chips/src/*.sv src/apple_ii_rev0_digital.sv tb/tb_rev0_wiring.sv
vvp work/board.vvp >work/board.log 2>&1 || { cat work/board.log; exit 1; }
cat work/board.log
grep -q 'PASS revision-0' work/board.log
