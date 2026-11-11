#!/bin/sh
# Run the complete S/360 M1 verification flow.
#
# Usage: ./run_all.sh [--quick]
#   --quick   skip the formal prove/cover tasks (lint, simulation and
#             synthesis only). The full flow is the default so that a plain
#             invocation cannot quietly skip the proofs.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MODE=${1:-}

sh "$HERE/run_lint.sh"
sh "$HERE/run_sim.sh"
sh "$HERE/run_synth.sh"

if [ "$MODE" = "--quick" ]; then
    echo "=== formal tasks skipped (--quick) ==="
else
    sh "$HERE/run_formal.sh"
fi

echo "S/360 M2 COMPLETE FLOW PASSED"
