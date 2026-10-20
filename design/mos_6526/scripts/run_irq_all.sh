#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/formal" "$HERE/work/irq" "$HERE/work/synth"
cd "$HERE/formal"
for task in bmc prove cover; do
    sby -f -d "$HERE/work/formal/irq_$task" mos_6526_irq.sby "$task"
done
verilator --lint-only -Wall "$HERE/src/mos_6526_irq.sv"
verilator --binary --timing -Wall -Wno-TIMESCALEMOD -j 4 --top-module tb_irq \
    --Mdir "$HERE/work/irq" "$HERE/src/mos_6526_irq.sv" "$HERE/tb/tb_irq.sv" > "$HERE/work/irq-build.log" 2>&1
"$HERE/work/irq/Vtb_irq" > "$HERE/work/irq-verilator.log" 2>&1
grep 'MOS 6526 IRQ PASS:' "$HERE/work/irq-verilator.log"
xezim --simulate --sv2017 --error-exit -s tb_irq "$HERE/src/mos_6526_irq.sv" \
    "$HERE/tb/tb_irq.sv" --max-time 100000ns -l "$HERE/work/irq-xezim.log"
grep 'MOS 6526 IRQ PASS:' "$HERE/work/irq-xezim.log"
yosys -Q -p "read_verilog -sv $HERE/src/mos_6526_irq.sv; synth -top mos_6526_irq; check; stat; write_json $HERE/work/synth/irq.json" \
    > "$HERE/work/synth/irq.log" 2>&1
echo 'MOS 6526 SAMPLED IRQ GATES PASS (revision races still required)'
