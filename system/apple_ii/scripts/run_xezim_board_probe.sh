#!/bin/sh
set -eu
# Tool probe, not a board regression. Xezim accepts this netlist but loses
# driven CPU data on the resolved system bus, so the testbench reports X where
# Icarus reports the value the packages drive. The failure is recorded in
# report/final_report.md and is not yet reduced to a minimal case; this script
# exists so the regression that exposes it stays reproducible.
cd "$(dirname "$0")/.."
python3 scripts/generate_rev0.py --check
mkdir -p work
if ! command -v xezim >/dev/null 2>&1; then
    echo 'SKIP: xezim is not installed in this image' >&2
    exit 2
fi
set +e
XEZIM_TWO_STATE=0 xezim --simulate --error-exit -s tb_rev0_wiring \
    ../../design/apple_ii_chips/src/*.sv src/apple_ii_rev0_digital.sv \
    tb/tb_rev0_wiring.sv --max-time 110us >work/xezim_board_probe.log 2>&1
status=$?
set -e
cat work/xezim_board_probe.log
if grep -q 'PASS revision-0' work/xezim_board_probe.log; then
    echo 'UNEXPECTED PASS: xezim no longer reproduces the resolved-bus defect' >&2
    exit 3
fi
echo "EXPECTED FAILURE: xezim board probe (status $status); see report item 6" >&2
exit 1
