#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
sh "$SYSTEM/scripts/run_lint.sh"
sh "$SYSTEM/scripts/run_sim.sh"
python3 "$SYSTEM/scripts/test_backend.py"
echo "SCELBI 8B complete flow passed"
