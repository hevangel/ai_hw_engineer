#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
python3 "$SYSTEM/scripts/prepare_images.py"
sh "$ROOT/design/intel_8272/scripts/run_all.sh"
sh "$ROOT/design/intel_8237/scripts/run_all.sh"
sh "$SYSTEM/scripts/build.sh"
cd "$SYSTEM/formal"
for task in bmc prove cover; do
  sby -f -d "$SYSTEM/work/formal/ibm_pc_bus_$task" ibm_pc_bus.sby "$task"
done
"$SYSTEM/work/obj/Vibm_pc" "$SYSTEM/work/reference" --board-tests "$SYSTEM/work/board.bin"
"$SYSTEM/work/obj/Vibm_pc" "$SYSTEM/work/reference" --disk-tests "$SYSTEM/work/disk.bin"
python3 "$SYSTEM/scripts/test_software.py"
python3 "$SYSTEM/scripts/test_backend.py"
python3 "$SYSTEM/scripts/test_waveform.py"
sh "$SYSTEM/scripts/run_synth.sh"
echo 'PASS: IBM PC complete virtual-platform verification'
