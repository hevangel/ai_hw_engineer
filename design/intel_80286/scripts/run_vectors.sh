#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
# Keep the pinned third-party oracle out of the source tree and tool image.
if [ ! -f "$WORK_DIR/oracle/unicorn/__init__.py" ]; then
    python3 -m pip install --target "$WORK_DIR/oracle" unicorn==2.1.4
fi
python3 "$SCRIPT_DIR/generate_vectors.py"
sh "$SCRIPT_DIR/build_runner.sh"
"$WORK_DIR/sim/Vintel_80286" --vectors "$WORK_DIR/vectors/registers.txt"
