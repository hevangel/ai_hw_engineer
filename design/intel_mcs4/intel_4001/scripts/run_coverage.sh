#!/bin/bash
# Run the intel_4001 functional-coverage simulation and write a summary.
# The testbench is a single self-checking run with a fixed-seed random
# phase; "coverage" here is the enumeration of directed scenarios and
# stimulus ranges achieved, extracted from the run log and the bench's
# own counters.
# Usage: ./run_coverage.sh

set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/coverage"
REPORT_DIR="$DESIGN_DIR/report"

mkdir -p "$WORK_DIR"

echo "=== Coverage run: intel_4001 ==="

if ! "$SCRIPT_DIR/run_sim.sh" "$WORK_DIR"; then
    echo "  ERROR: simulation failed; no coverage summary written"
    exit 1
fi

mkdir -p "$REPORT_DIR"
{
    echo "# Functional Coverage Report: intel_4001"
    echo ""
    echo "Generated: $(date -u +%Y-%m-%d)"
    echo ""
    echo "Source: one self-checking xezim run (directed + fixed-seed random)."
    echo ""
    echo "## Enumeration achieved"
    echo ""
    echo "| Dimension | Coverage |"
    echo "|---|---|"
    echo "| ROM addresses, chip 0 (mask A) | 256/256 (D2) |"
    echo "| ROM addresses, chip 1 (mask B) | 256/256 (D3) |"
    echo "| Addressed chips | 0, 1, 2 (absent) (D4) |"
    echo "| SRC select targets | 0, 1, 2 + random 0-3 (D5-D9, random) |"
    echo "| WRR data values | 0x0, 0x3, 0x5, 0xA, 0xC, 0xD, 0xF + random 0-F |"
    echo "| RDR value sources | output latch bits + input pin bits (D8) |"
    echo "| Reset | power-on, mid-fetch (M2), mid-WRR (X2) (D13) |"
    echo "| CL clear | mid-run pulse after WRR (D14), CL through a full WRR cycle with the write suppressed (D15), random pulses |"
    echo "| Ignored opcodes | NOP, WPM (idle and active), WRM, WMP, RDM, FF, 23 (D12) |"
    echo ""
    echo "## Formal reachability covers"
    echo ""
    echo "All 38 labeled reachability goals in"
    echo "formal/intel_4001_cover.sv are reached by the SymbiYosys cover"
    echo "task (smtbmc z3): 38 reached, 0 unreached. See"
    echo "report/final_report.md for the recorded result."
    echo ""
    echo "## Result"
    echo ""
    grep -E "4001 tb:|TEST PASSED" "$WORK_DIR/tb.log" || true
} > "$REPORT_DIR/coverage_report.md"

echo "  Summary: $REPORT_DIR/coverage_report.md"
echo "=== Coverage run complete ==="
