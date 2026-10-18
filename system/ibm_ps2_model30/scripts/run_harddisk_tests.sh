#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
verilator --cc --exe --build -j 4 -Wall --assert --top-module model30_fixed_disk \
    -GCYLINDERS=4 -GHEADS=2 -GSECTORS=3 --Mdir "$SYSTEM/work/hd_obj" \
    "$SYSTEM/src/model30_fixed_disk.sv" "$SYSTEM/tb/hdd_controller_test.cpp" \
    > "$SYSTEM/work/hdd_build.log" 2>&1
"$SYSTEM/work/hd_obj/Vmodel30_fixed_disk" "$SYSTEM/tb/hdd_check_vectors.hex"
"$SYSTEM/work/obj/Vibm_ps2_model30" "$SYSTEM/work/reference" \
    --harddisk-tests "$SYSTEM/work/harddisk.bin"
