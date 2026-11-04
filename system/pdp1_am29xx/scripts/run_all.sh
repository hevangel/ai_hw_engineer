#!/bin/sh
# Full local regression: lint, rebuild, every directed test, synthesis.
# The SIMH oracle comparison runs in its own pinned container; see the report.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work"
cd "$ROOT"

sh "$SYSTEM/scripts/run_lint.sh"
sh "$SYSTEM/scripts/build_sim.sh"

for test in smoke arith logic shift jumps skip index operate demo; do
  python3 "$SYSTEM/scripts/pdp1asm.py" "$SYSTEM/tests/$test.pdp1" \
      --hex "$SYSTEM/work/$test.hex" --listing "$SYSTEM/work/$test.lst" > /dev/null
  "$SYSTEM/work/obj/Vpdp1_am29xx" --batch \
      --image "$SYSTEM/work/$test.hex" \
      --trace "$SYSTEM/work/$test.trace" --max-micro 400 > "$SYSTEM/work/$test.state"
  echo "$test: $(wc -l < "$SYSTEM/work/$test.trace") instructions traced"
done

sh "$SYSTEM/scripts/run_synth.sh"
echo "regression complete"
