#!/bin/sh
# Retained diagnostic: coverage instrumentation currently changes the RAM result.
set -eu
cd "$(dirname "$0")/.."
. scripts/sources.sh
XEZIM_COV_DB=work/diagnostic_coverage.json xezim --code-coverage --code-coverage-scope tb_top.dut --simulate --sv2017 --error-exit -s tb_top $SOURCES tb/tb_top.sv --max-time 1000000ns -l work/xezim_coverage_diagnostic.log
grep 'PASS IIe xezim/Verilator' work/xezim_coverage_diagnostic.log
