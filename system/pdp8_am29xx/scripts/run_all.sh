#!/bin/sh
# Complete PDP-8 reconstruction verification: lint, build, instruction-set
# agreement against the independent reference model, front-panel and
# interrupt tests, and a synthesis check.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$SYSTEM/work"

echo "== Microcode"
python3 "$SYSTEM/scripts/gen_microcode.py" --source "$SYSTEM/src/pdp8_microcode.asm" \
    --out "$SYSTEM/src/pdp8_ucode.sv" --listing "$SYSTEM/work/ucode.lst"

echo "== Build"
sh "$SYSTEM/scripts/build.sh"

echo "== Instruction-set agreement (RTL vs independent ISS)"
python3 "$SYSTEM/scripts/run_isa_tests.py" --binary "$SYSTEM/work/obj_tb_top/Vtb_top" \
    --seeds 40

echo "== Front panel and interrupt"
"$SYSTEM/work/obj_tb_panel/Vtb_panel"

echo "== Synthesis"
sh "$SYSTEM/scripts/run_synth.sh"

echo "PASS: PDP-8 reconstruction verification complete"
