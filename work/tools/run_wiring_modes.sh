#!/bin/sh
set -eu
cd /work/system/apple_ii
mkdir -p work/timing
for m in typ max zero; do
    python3 scripts/generate_rev0.py --timing "$m" \
        --out-src "work/timing/board_$m.sv" --out-json "work/timing/board_$m.json" >/dev/null
    iverilog -g2012 -s tb_rev0_wiring -o "work/timing/w_$m.vvp" \
        ../../design/apple_ii_chips/src/*.sv "work/timing/board_$m.sv" tb/tb_rev0_wiring.sv 2>/dev/null
    if vvp "work/timing/w_$m.vvp" >"work/timing/w_$m.log" 2>&1; then
        status=PASS
    else
        status=FAIL
    fi
    echo "--- $m: $status"
    tail -3 "work/timing/w_$m.log"
done
