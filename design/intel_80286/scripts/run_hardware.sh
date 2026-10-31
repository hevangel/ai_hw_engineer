#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
python3 -m unittest discover -s "$SCRIPT_DIR" -p 'test_*hardware*.py'
python3 "$SCRIPT_DIR/prepare_hardware_tests.py"
python3 "$SCRIPT_DIR/prepare_protection_hardware.py"
sh "$SCRIPT_DIR/build_runner.sh"
HARDWARE_RUNNER="$WORK_DIR/sim/Vintel_80286"
"$HARDWARE_RUNNER" --hardware "$WORK_DIR/hardware/vectors.txt"
"$HARDWARE_RUNNER" --hardware "$WORK_DIR/hardware/protection_vectors.txt"
python3 "$SCRIPT_DIR/test_hardware_replay.py"
python3 "$SCRIPT_DIR/test_protection_hardware_replay.py"
