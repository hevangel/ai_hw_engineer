#!/bin/sh
set -eu
cd /work/system/apple_ii
mkdir -p work/timing
# Variant A: datasheet TTL delays only (memory parts keep the legacy 5 ns).
# Variant B: datasheet DRAM access only (TTL keeps the legacy 5 ns).
python3 - <<'PY'
import json
from pathlib import Path
base = json.loads(Path('board/timing.json').read_text())
for name, overrides in {
    'ttl': {'4116': 5, 'ROM_Chip': 5, '2513': 5},
    'dram': {k: 5 for k in base['parts'] if k not in ('4116', 'ROM_Chip', '2513')},
}.items():
    table = json.loads(json.dumps(base))
    for part, value in overrides.items():
        entry = table['parts'][part]
        entry.pop('same_as', None)
        entry['typ_ns'] = value
        entry['max_ns'] = value
    Path(f'work/timing/timing_{name}.json').write_text(json.dumps(table))
PY
for name in ttl dram; do
    cp "work/timing/timing_$name.json" work/timing/timing_active.json
    cp board/timing.json work/timing/timing_original.json
    cp "work/timing/timing_$name.json" board/timing.json
    python3 scripts/generate_rev0.py --timing typ --out-src "work/timing/board_$name.sv" \
        --out-json "work/timing/board_$name.json" >/dev/null
    cp work/timing/timing_original.json board/timing.json
    iverilog -g2012 -DAPPLE_II_CPU_MODULE=apple_ii_rev0_authored -s tb_rev0_boot \
        -o "work/timing/boot_$name.vvp" \
        ../../design/apple_ii_chips/src/*.sv ../../design/apple_ii_chips/src/analog/*.sv \
        ../../design/mos_6502_cycle/src/mos_6502_cycle.sv ../../design/mos_6502_cycle/src/a2_mos6502.sv \
        "work/timing/board_$name.sv" src/apple_ii_rev0_peripherals.sv src/apple_ii_*output.sv \
        src/apple_ii_rev0_authored.sv tb/tb_rev0_boot.sv 2>/dev/null
    timeout 900 vvp "work/timing/boot_$name.vvp" >"work/timing/boot_$name.log" 2>&1 || true
    echo "=== $name ==="
    tail -2 "work/timing/boot_$name.log"
    python3 scripts/check_monitor_video.py 2>&1 | tail -1
    cp work/monitor_video.csv "work/timing/monitor_video_$name.csv"
done
