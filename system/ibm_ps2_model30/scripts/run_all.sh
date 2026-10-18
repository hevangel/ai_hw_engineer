#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$SYSTEM/scripts/prepare_images.py"
sh "$SYSTEM/scripts/run_formal.sh"
sh "$SYSTEM/scripts/build.sh"
"$SYSTEM/work/obj/Vibm_ps2_model30" "$SYSTEM/work/reference" --board-tests "$SYSTEM/work/board.bin"
"$SYSTEM/work/obj/Vibm_ps2_model30" "$SYSTEM/work/reference" --disk-tests "$SYSTEM/work/disk.bin"
sh "$SYSTEM/scripts/run_harddisk_tests.sh"
python3 "$SYSTEM/scripts/test_hdd_persistence.py"
python3 "$SYSTEM/scripts/test_nvram.py"
python3 "$SYSTEM/scripts/test_waveform.py"
python3 "$SYSTEM/scripts/test_backend.py"
sh "$SYSTEM/scripts/run_synth.sh"
python3 "$SYSTEM/scripts/test_software.py"
python3 "$SYSTEM/scripts/test_display_software.py"
python3 "$SYSTEM/scripts/test_harddisk.py"
echo 'PASS: IBM PS/2 Model 30 complete verification flow'
