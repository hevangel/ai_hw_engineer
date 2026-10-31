#!/bin/sh
# Focused feedback only. run_all.sh remains the full formal-first release gate.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
python3 "$SCRIPT_DIR/preflight.py"
sh "$SCRIPT_DIR/build_runner.sh"
sh "$SCRIPT_DIR/run_bus_owner.sh"
"$WORK_DIR/sim/Vintel_80286" --ud
"$WORK_DIR/sim/Vintel_80286" --protection
"$WORK_DIR/sim/Vintel_80286" --system
"$WORK_DIR/sim/Vintel_80286" --processor-extension
"$WORK_DIR/sim/Vintel_80286" --system-decode
"$WORK_DIR/sim/Vintel_80286" --selector-exec
"$WORK_DIR/sim/Vintel_80286" --protected-segments
PROTECTED_MODE_RUN_NAME="protected_mode_dev_$(date -u +%Y%m%dT%H%M%SZ)"
bash "$SCRIPT_DIR/run_protected_mode_replay.sh" "$PROTECTED_MODE_RUN_NAME"
if [ -f "$WORK_DIR/hardware/protection_vectors.txt" ]; then
    "$WORK_DIR/sim/Vintel_80286" --hardware "$WORK_DIR/hardware/protection_vectors.txt"
else
    echo 'Physical protection vectors absent; run run_hardware.sh before release.'
fi
echo 'Focused development checks passed; full release verification still required.'
