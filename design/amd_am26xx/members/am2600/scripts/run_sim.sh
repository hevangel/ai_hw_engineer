#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/sim"
mkdir -p "$WORK_DIR"
echo "=== Am2600 Verilator simulation ==="
verilator --binary -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL --timing -j 4 \
    --top-module tb_top --Mdir "$WORK_DIR/obj" \
    "$DESIGN_DIR/src/am2600.sv" "$DESIGN_DIR/tb/tb_top.sv" \
    > "$WORK_DIR/build.log" 2>&1
"$WORK_DIR/obj/Vtb_top" > "$WORK_DIR/verilator.log" 2>&1
grep -q 'am2600 TEST PASSED' "$WORK_DIR/verilator.log"
echo "=== Am2600 Xezim simulation ==="
xezim --simulate --sv2017 --error-exit -s tb_top \
    "$DESIGN_DIR/src/am2600.sv" "$DESIGN_DIR/tb/tb_top.sv" \
    --max-time 2000000000ns --fst "$WORK_DIR/am2600.fst" \
    -l "$WORK_DIR/sim.log"
grep -q 'am2600 TEST PASSED' "$WORK_DIR/sim.log"
echo "Am2600 SIM PASSED"
