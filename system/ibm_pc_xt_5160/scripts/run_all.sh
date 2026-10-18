#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$SYSTEM/scripts/prepare_images.py"
bash "$SYSTEM/scripts/run_formal.sh"
bash "$SYSTEM/scripts/build.sh"
bash "$SYSTEM/scripts/run_controller.sh"
"$SYSTEM/work/obj/Vibm_pc_xt_5160" "$SYSTEM/work/reference" --fpu-tests "$SYSTEM/work/fpu.bin"
python3 "$SYSTEM/scripts/make_demo_disk.py"
unset IBM_XT_RESUME
python3 "$SYSTEM/scripts/test_software.py"
python3 "$SYSTEM/scripts/test_backend.py"
bash "$SYSTEM/scripts/run_synth.sh"
