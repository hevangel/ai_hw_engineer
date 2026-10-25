#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/coverage"
echo "=== Intel 3404 RTL code coverage ==="
XEZIM_COV_DB="$HERE/work/coverage/rtl.json" \
xezim --simulate --sv2017 --error-exit --code-coverage \
    --code-coverage-scope tb_top.dut -s tb_top \
    "$HERE/src/intel_3404.sv" "$HERE/tb/tb_top.sv" \
    --max-time 2000000000ns -l "$HERE/work/coverage/sim.log"
grep 'intel_3404 TEST PASSED' "$HERE/work/coverage/sim.log"
test -s "$HERE/work/coverage/rtl.json"
python3 "$HERE/scripts/summarize_coverage.py" "intel_3404" \
    < "$HERE/work/coverage/rtl.json" \
    > "$HERE/work/coverage/summary.txt"
cat "$HERE/work/coverage/summary.txt"
