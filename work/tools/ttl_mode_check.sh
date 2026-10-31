#!/bin/sh
set -eu
cd /work/system/apple_ii
mkdir -p work/timing
mode=${1:-max}
python3 - "$mode" <<'PY'
import json, sys
from pathlib import Path
mode = sys.argv[1]
base = json.loads(Path('board/timing.json').read_text())
# TTL packages take the requested datasheet mode; memory parts keep the ideal
# 5 ns placeholder until the 4116 access model is reworked (review item P3).
memory = ('4116', 'ROM_Chip', '2513')
for part, entry in base['parts'].items():
    if part in memory:
        entry.pop('same_as', None)
        entry['typ_ns'] = 5
        entry['max_ns'] = 5
Path('work/timing/timing_ttl_only.json').write_text(json.dumps(base))
PY
cp work/timing/timing_ttl_only.json work/timing/timing_saved.json
cp board/timing.json work/timing/timing_pristine.json
cp work/timing/timing_ttl_only.json board/timing.json
python3 scripts/generate_rev0.py --timing "$mode" --out-src "work/timing/board_ttl_$mode.sv" \
    --out-json "work/timing/board_ttl_$mode.json" >/dev/null
cp work/timing/timing_pristine.json board/timing.json
iverilog -g2012 -s tb_rev0_wiring -o "work/timing/w_ttl_$mode.vvp" \
    ../../design/apple_ii_chips/src/*.sv "work/timing/board_ttl_$mode.sv" tb/tb_rev0_wiring.sv 2>/dev/null
timeout 300 vvp "work/timing/w_ttl_$mode.vvp" >"work/timing/w_ttl_$mode.log" 2>&1 || true
echo "wiring: $(tail -2 "work/timing/w_ttl_$mode.log" | head -1)"
iverilog -g2012 -DAPPLE_II_CPU_MODULE=apple_ii_rev0_authored -s tb_rev0_boot \
    -o "work/timing/boot_ttl_$mode.vvp" \
    ../../design/apple_ii_chips/src/*.sv ../../design/apple_ii_chips/src/analog/*.sv \
    ../../design/mos_6502_cycle/src/mos_6502_cycle.sv ../../design/mos_6502_cycle/src/a2_mos6502.sv \
    "work/timing/board_ttl_$mode.sv" src/apple_ii_rev0_peripherals.sv src/apple_ii_*output.sv \
    src/apple_ii_rev0_authored.sv tb/tb_rev0_boot.sv 2>/dev/null
timeout 900 vvp "work/timing/boot_ttl_$mode.vvp" >"work/timing/boot_ttl_$mode.log" 2>&1 || true
echo "boot: $(tail -2 "work/timing/boot_ttl_$mode.log" | head -1)"
python3 scripts/check_monitor_video.py 2>&1 | tail -1
cp work/monitor_video.csv "work/timing/monitor_video_ttl_$mode.csv"
