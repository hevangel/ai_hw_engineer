#!/bin/bash
# Run simulation with xezim
# Usage: ./run_sim.sh [test_name] [+seed=N]

set -e

CHIP_NAME=$(basename $(dirname $(dirname $(realpath $0))))
DESIGN_DIR=$(dirname $(dirname $(realpath $0)))
UVM_HOME=${UVM_HOME:-$(realpath $DESIGN_DIR/../../libs/uvm/1800.2-2017)}
WORK_DIR=$DESIGN_DIR/work/sim

# Default test
TEST_NAME=${1:-base_test}
shift 2>/dev/null || true

# Create work directory
mkdir -p $WORK_DIR

echo "=== Running simulation: $CHIP_NAME / $TEST_NAME ==="
echo "  Design dir: $DESIGN_DIR"
echo "  UVM:        $UVM_HOME"

# Collect source files
SRC_FILES=$(find $DESIGN_DIR/src -name "*.sv" -o -name "*.v" | sort)
TB_FILES=$(find $DESIGN_DIR/tb -name "*.sv" | sort)

# Run xezim
xezim --simulate \
  -s tb_top \
  -I $UVM_HOME/src \
  -I $DESIGN_DIR/src \
  -I $DESIGN_DIR/tb \
  -D UVM_NO_DPI \
  -D UVM_REPORT_DISABLE_FILE_LINE \
  -D SIMULATION \
  $UVM_HOME/src/uvm_pkg.sv \
  $SRC_FILES \
  $TB_FILES \
  +UVM_TESTNAME=$TEST_NAME \
  --fst $WORK_DIR/${TEST_NAME}.fst \
  --max-time 1000000 \
  -l $WORK_DIR/${TEST_NAME}.log \
  "$@"

echo "=== Simulation complete ==="
echo "  Log:      $WORK_DIR/${TEST_NAME}.log"
echo "  Waveform: $WORK_DIR/${TEST_NAME}.fst"
