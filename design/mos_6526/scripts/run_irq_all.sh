#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/formal" "$HERE/work/synth"
cd "$HERE/formal"
verilator --lint-only -Wall "$HERE/src/mos_6526_irq.sv"
for profile in irq irq_no_loss; do
    for task in bmc prove cover; do
        sby -f -d "$HERE/work/formal/${profile}_$task" "mos_6526_$profile.sby" "$task"
    done
    verilator --binary --timing -Wall -Wno-TIMESCALEMOD -j 4 --top-module "tb_$profile" \
        --Mdir "$HERE/work/$profile" "$HERE/src/mos_6526_irq.sv" "$HERE/tb/tb_irq.sv" \
        "$HERE/tb/tb_irq_no_loss.sv" > "$HERE/work/$profile-build.log" 2>&1
    "$HERE/work/$profile/Vtb_$profile" > "$HERE/work/$profile-verilator.log" 2>&1
    grep 'MOS 6526 IRQ PASS:' "$HERE/work/$profile-verilator.log"
    xezim --simulate --sv2017 --error-exit -s "tb_$profile" "$HERE/src/mos_6526_irq.sv" \
        "$HERE/tb/tb_irq.sv" "$HERE/tb/tb_irq_no_loss.sv" --max-time 100000ns -l "$HERE/work/$profile-xezim.log"
    grep 'MOS 6526 IRQ PASS:' "$HERE/work/$profile-xezim.log"
    setting=''
    if [ "$profile" = irq_no_loss ]; then setting='chparam -set TIMER_B_READ_LOSS 0 mos_6526_irq;'; fi
    yosys -Q -p "read_verilog -sv $HERE/src/mos_6526_irq.sv; $setting synth -top mos_6526_irq; check; stat; write_json $HERE/work/synth/$profile.json" \
        > "$HERE/work/synth/$profile.log" 2>&1
done
echo 'MOS 6526 SAMPLED IRQ GATES PASS (revision races still required)'
