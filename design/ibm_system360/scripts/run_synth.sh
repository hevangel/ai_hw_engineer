#!/bin/sh
# Synthesis smoke test: the M1 core must be synthesizable without latches or
# undriven logic. Yosys reports the cell counts used in the design report.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/synth"

echo "=== ibm_s360 M1 core synthesis (Yosys) ==="
# Run from src/ so the `include of ibm_s360_defs.svh resolves. Do not use -q:
# the cell statistics are the evidence this script exists to produce.
(cd "$HERE/src" && yosys -p "
    read_verilog -sv ibm_s360_alu.sv ibm_s360_addr.sv ibm_s360_psw.sv ibm_s360_cpu.sv
    hierarchy -check -top ibm_s360_cpu
    synth -top ibm_s360_cpu
    check
    stat
") > "$HERE/work/synth/yosys.log" 2>&1

echo "--- cell statistics (hierarchy and per module) ---"
grep -E '^=== [a-z_0-9]+ ===$|^[0-9]+ cells$' "$HERE/work/synth/yosys.log" | tail -12
echo "--- structural check ---"
grep -E 'Found and reported' "$HERE/work/synth/yosys.log" | tail -3
if grep -qE 'Latch inferred' "$HERE/work/synth/yosys.log"; then
    echo "ERROR: latches inferred:"
    grep -E 'Latch inferred' "$HERE/work/synth/yosys.log"
    exit 1
fi
echo "no latches inferred"
echo "=== synthesis completed (log: work/synth/yosys.log) ==="
