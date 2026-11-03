#!/bin/sh
set -eu
# Negative control for the cross-core differential: build the same driver with
# one corrupted read in core B and require the comparison to detect it. Without
# this, a harness that silently matched would look identical to a passing one.
cd "$(dirname "$0")/.."
mkdir -p work
verilator --cc --exe --build -j 4 -Wall --top-module dual_6502_top \
    --Mdir work/dual_neg -CFLAGS "-DINJECT_FAULT" \
    "$(pwd)/src/mos_6502.sv" "$(pwd)/cycle/src/mos_6502_cycle.sv" \
    "$(pwd)/compare/dual_6502_top.sv" "$(pwd)/compare/dual_test.cpp"
set +e
work/dual_neg/Vdual_6502_top > work/dual_neg.log 2>&1
rc=$?
set -e
cat work/dual_neg.log
if [ "$rc" -eq 0 ]; then
    echo 'FAIL negative control: a corrupted core B still matched core A' >&2
    exit 1
fi
grep -q 'DIFF at instruction' work/dual_neg.log
echo 'PASS differential negative control: injected read fault detected'
