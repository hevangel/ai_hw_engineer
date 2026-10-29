#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Datasheet timing gate. board/timing.json holds per-part typical and maximum
# delays; memory packages still carry the ideal placeholder (see the report).
# Scope is deliberate and stated in report/final_report.md:
#   - the directed socket test is certified only at typical delays, because its
#     stimulus and fixed waits still encode zero-delay phase relationships;
#   - the Monitor frame is captured at both delays but not compared, because
#     the capture samples 10 ns after the pixel clock, before a 25 ns
#     clock-to-Q. A weaker comparison here would hide that harness gap.
mkdir -p work/timing
python3 scripts/fetch_board_references.py
for mode in typ max; do
    python3 scripts/generate_rev0.py --timing "$mode" \
        --out-src "work/timing/board_$mode.sv" \
        --out-json "work/timing/board_$mode.json"
    if [ "$mode" = typ ]; then
        iverilog -g2012 -s tb_rev0_wiring -o "work/timing/wiring_$mode.vvp" \
            ../../design/apple_ii_chips/src/*.sv "work/timing/board_$mode.sv" \
            tb/tb_rev0_wiring.sv
        vvp "work/timing/wiring_$mode.vvp" >"work/timing/wiring_$mode.log" 2>&1 \
            || { cat "work/timing/wiring_$mode.log"; exit 1; }
        grep -q 'PASS revision-0' "work/timing/wiring_$mode.log"
        echo "PASS revision-0 socket wiring at $mode delays"
    fi
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
echo 'PASS datasheet gate (typical socket, typical/maximum Monitor boot); maximum-delay socket and frame comparison remain open'
