#!/bin/bash
# Run the direct (non-UVM) self-checking testbench with xezim
# Usage: ./run_sim.sh [tb_top] [max_time]
#   tb_top    top-level module of the testbench (default: tb_intel_4002)
#   max_time  simulation time limit passed to --max-time (default: 10ms)
#
# xezim does not always exit nonzero when a $display-based check fails, so
# this script greps the log for FAIL/TEST FAILED and exits nonzero on either.

set -e

DESIGN_DIR=$(dirname $(dirname $(realpath $0)))
CHIP_NAME=$(basename $DESIGN_DIR)
WORK_DIR=$DESIGN_DIR/work/sim

TB_TOP=${1:-tb_intel_4002}
MAX_TIME=${2:-10000000}

mkdir -p $WORK_DIR

echo "=== Running simulation: $CHIP_NAME / $TB_TOP ==="

SRC_FILES=$(ls $DESIGN_DIR/src/*.sv)
TB_FILES=$(ls $DESIGN_DIR/tb/*.sv)

LOG=$WORK_DIR/tb.log

set +e
xezim --simulate \
  -s $TB_TOP \
  -I $DESIGN_DIR/src \
  -I $DESIGN_DIR/tb \
  --fst $WORK_DIR/tb.fst \
  --max-time $MAX_TIME \
  -l $LOG \
  $SRC_FILES $TB_FILES
XEZIM_RC=$?
set -e

echo "  xezim exit code: $XEZIM_RC"
echo "  Log:      $LOG"
echo "  Waveform: $WORK_DIR/tb.fst"

# Grep the log for failures and the final verdict
FAILS=$(grep -c "FAIL" $LOG || true)
if grep -q "TEST PASSED" $LOG && [ "$FAILS" -eq 0 ] && [ $XEZIM_RC -eq 0 ]; then
    echo "=== Simulation PASSED ==="
    grep "TEST PASSED" $LOG
    exit 0
fi

echo "=== Simulation FAILED ==="
grep "TEST FAILED" $LOG || true
echo "  FAIL lines in log: $FAILS"
exit 1
