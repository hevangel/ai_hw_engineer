#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/generate_rev0.py --check
mkdir -p work
case "${SIMULATOR:-xezim}" in
    xezim)
        XEZIM_TWO_STATE=0 xezim --simulate --error-exit -s tb_rev0_wiring \
            ../../design/apple_ii_chips/src/*.sv src/apple_ii_rev0_digital.sv \
            tb/tb_rev0_wiring.sv --max-time 110us >work/board.log 2>&1 || { cat work/board.log; exit 1; }
        cat work/board.log
        grep -q 'PASS revision-0' work/board.log ;;
    iverilog)
        mkdir -p work
        iverilog -g2012 -s tb_rev0_wiring -o work/board.vvp \
            ../../design/apple_ii_chips/src/*.sv src/apple_ii_rev0_digital.sv tb/tb_rev0_wiring.sv
        vvp work/board.vvp >work/board.log 2>&1 || { cat work/board.log; exit 1; }
        cat work/board.log
        grep -q 'PASS revision-0' work/board.log ;;
    *) echo "Unknown SIMULATOR: $SIMULATOR" >&2; exit 2 ;;
esac
