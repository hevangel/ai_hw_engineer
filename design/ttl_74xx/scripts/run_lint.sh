#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python3 "$SCRIPT_DIR/run_library.py" lint "$@"
sh "$SCRIPT_DIR/run_74181_lint.sh"
