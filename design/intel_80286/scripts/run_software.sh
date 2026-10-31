#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
# Keep the pinned third-party oracle out of the source tree and tool image.
if [ ! -f "$WORK_DIR/oracle/unicorn/__init__.py" ]; then
    python3 -m pip install --target "$WORK_DIR/oracle" unicorn==2.1.4
fi
python3 "$SCRIPT_DIR/prepare_software.py"
sh "$SCRIPT_DIR/build_runner.sh"
"$WORK_DIR/sim/Vintel_80286" --software "$WORK_DIR/software/atbios.bin"
python3 "$SCRIPT_DIR/generate_firmware_trace.py"
"$WORK_DIR/sim/Vintel_80286" --firmware "$WORK_DIR/software/oracle_trace.txt"
python3 "$SCRIPT_DIR/generate_bios_decimal_trace.py"
"$WORK_DIR/sim/Vintel_80286" --bios-decimal "$WORK_DIR/software/decimal_trace.txt"
"$WORK_DIR/sim/Vintel_80286" --bios-irq "$WORK_DIR/software/atbios.bin"
"$WORK_DIR/sim/Vintel_80286" --bios-system "$WORK_DIR/software/atbios.bin"
sh "$SCRIPT_DIR/run_at_timer_bios.sh" "$WORK_DIR/software/atbios.bin"
sh "$SCRIPT_DIR/run_at_bios_native.sh" "$WORK_DIR/software/atbios.bin"
