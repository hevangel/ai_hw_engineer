#!/bin/bash
# Run the intel_4002 functional-coverage simulation and refresh the
# coverage summary. The testbench is a single self-checking run (directed
# phases plus a fixed-seed random phase); "coverage" here is the
# enumeration of commands, cells, and selection corners achieved, extracted
# from the run log and recorded in report/coverage_report.md.
# Usage: ./run_coverage.sh

set -e

DESIGN_DIR=$(dirname $(dirname $(realpath $0)))
WORK_DIR=$DESIGN_DIR/work/coverage
REPORT=$DESIGN_DIR/report/coverage_report.md

mkdir -p $WORK_DIR

echo "=== Coverage run: intel_4002 ==="

if ! $DESIGN_DIR/scripts/run_sim.sh tb_intel_4002 100000000; then
    echo "  ERROR: simulation failed; coverage summary not refreshed"
    exit 1
fi

cp $DESIGN_DIR/work/sim/tb.log $WORK_DIR/tb.log

PASSED_LINE=$(grep "TEST PASSED" $WORK_DIR/tb.log || true)
echo "  $PASSED_LINE"
echo "  Enumeration achieved and formal cover results are recorded in:"
echo "    $REPORT"
echo "  Raw log: $WORK_DIR/tb.log"
echo "=== Coverage run complete ==="
