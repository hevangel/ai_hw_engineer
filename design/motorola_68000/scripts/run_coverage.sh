#!/bin/bash
# Run simulation with coverage and generate reports
# Usage: ./run_coverage.sh [test_list_file]

set -e

CHIP_NAME=$(basename $(dirname $(dirname $(realpath $0))))
DESIGN_DIR=$(dirname $(dirname $(realpath $0)))
UVM_HOME=${UVM_HOME:-$(realpath $DESIGN_DIR/../../libs/uvm/1800.2-2017)}
WORK_DIR=$DESIGN_DIR/work/coverage
REPORT_DIR=$DESIGN_DIR/report/coverage

# Create directories
mkdir -p $WORK_DIR $REPORT_DIR

echo "=== Running coverage regression: $CHIP_NAME ==="

# Default test list or from file
if [ -n "$1" ] && [ -f "$1" ]; then
    TESTS=$(cat $1 | grep -v '^#' | grep -v '^\s*$')
else
    TESTS=${1:-base_test}
fi

# Collect source files
SRC_FILES=$(find $DESIGN_DIR/src -name "*.sv" -o -name "*.v" | sort)
TB_FILES=$(find $DESIGN_DIR/tb -name "*.sv" | sort)

PASS_COUNT=0
FAIL_COUNT=0

for test in $TESTS; do
    echo "--- Running test: $test ---"

    if xezim --simulate \
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
      +UVM_TESTNAME=$test \
      --max-time 1000000 \
      -l $WORK_DIR/${test}.log \
      +seed=$RANDOM; then
        echo "  PASS: $test"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $test"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

# Generate coverage summary
cat > $REPORT_DIR/coverage_summary.md << EOF
# Coverage Summary: $CHIP_NAME

Generated: $(date)

## Test Results

| Test | Status |
|------|--------|
EOF

for test in $TESTS; do
    if grep -q "UVM_ERROR : 0" $WORK_DIR/${test}.log 2>/dev/null; then
        echo "| $test | PASS |" >> $REPORT_DIR/coverage_summary.md
    else
        echo "| $test | FAIL |" >> $REPORT_DIR/coverage_summary.md
    fi
done

cat >> $REPORT_DIR/coverage_summary.md << EOF

## Summary

- Total tests: $((PASS_COUNT + FAIL_COUNT))
- Passed: $PASS_COUNT
- Failed: $FAIL_COUNT

## Coverage Metrics

> Note: Coverage metrics require tool-specific extraction.
> Run individual tools (xezim, Verilator --coverage) for detailed numbers.
EOF

echo ""
echo "=== Coverage regression summary ==="
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"
echo "  Report: $REPORT_DIR/coverage_summary.md"
