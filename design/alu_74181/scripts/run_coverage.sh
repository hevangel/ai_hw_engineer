#!/bin/sh
# Re-run all functional-coverage regressions inside ai-hw-engineer:latest.
# The exhaustive test covers the complete 2^14 functional input space; the UVM
# test independently covers all 64 mode/selector/carry bins.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$SCRIPT_DIR/run_sim.sh" all

echo "Functional coverage evidence is documented in report/coverage_report.md"
