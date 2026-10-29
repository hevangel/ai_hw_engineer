#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Datasheet timing gate. board/timing.json holds per-part typical and maximum
# delays; memory packages still carry the ideal placeholder (see the report).
# Scope:
#   - the directed socket test runs at typical and maximum delays; it samples
#     read data at the phi2 falling edge, where a 6502 latches it, and prints
#     the measured arrival offset for each bank;
#   - the unmodified Monitor boot runs at typical and maximum delays;
#   - the frame comparison is not run here. composite_sync is produced after a
#     deeper gate chain than the counter outputs the oracle derives it from, so
#     at datasheet delays the same-instant comparison cannot hold: no constant
#     dot shift reconciles it (measured in report/final_report.md). The frame
#     gate therefore stays on the legacy board in run_authored_boot.sh.
mkdir -p work/timing
python3 scripts/fetch_board_references.py
for mode in typ max; do
    python3 scripts/generate_rev0.py --timing "$mode" \
        --out-src "work/timing/board_$mode.sv" \
        --out-json "work/timing/board_$mode.json"
    iverilog -g2012 -s tb_rev0_wiring -o "work/timing/wiring_$mode.vvp" \
        ../../design/apple_ii_chips/src/*.sv "work/timing/board_$mode.sv" \
        tb/tb_rev0_wiring.sv
    vvp "work/timing/wiring_$mode.vvp" >"work/timing/wiring_$mode.log" 2>&1 \
        || { cat "work/timing/wiring_$mode.log"; exit 1; }
    grep -q 'PASS revision-0 socket wiring' "work/timing/wiring_$mode.log"
    grep 'READ row' "work/timing/wiring_$mode.log" | sed "s/^/  $mode: /"
    echo "PASS revision-0 socket wiring at $mode delays"
    iverilog -g2012 -DAPPLE_II_CPU_MODULE=apple_ii_rev0_authored -s tb_rev0_boot \
        -o "work/timing/boot_$mode.vvp" \
        ../../design/apple_ii_chips/src/*.sv ../../design/apple_ii_chips/src/analog/*.sv \
        ../../design/mos_6502_cycle/src/mos_6502_cycle.sv ../../design/mos_6502_cycle/src/a2_mos6502.sv \
        "work/timing/board_$mode.sv" src/apple_ii_rev0_peripherals.sv src/apple_ii_*output.sv \
        src/apple_ii_rev0_authored.sv tb/tb_rev0_boot.sv
    vvp "work/timing/boot_$mode.vvp" >"work/timing/boot_$mode.log" 2>&1 \
        || { cat "work/timing/boot_$mode.log"; exit 1; }
    grep -q 'PASS historical Monitor' "work/timing/boot_$mode.log"
    echo "PASS historical Monitor boot at $mode delays"
done
echo 'PASS datasheet timing gate: socket wiring and Monitor boot at typical and maximum delays; frame comparison stays on the legacy board (see report)'
