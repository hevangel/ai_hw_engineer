#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/coverage"
echo "=== 8237A RTL code coverage ==="
XEZIM_COV_DB="$HERE/work/coverage/rtl.json" \
xezim --simulate --sv2017 --error-exit --code-coverage \
    --code-coverage-scope tb_top.dut -s tb_top \
    "$HERE/src/intel_8237.sv" "$HERE/tb/tb_top.sv" \
    --max-time 5000000ns -l "$HERE/work/coverage/sim.log"
grep '8237A TEST PASSED' "$HERE/work/coverage/sim.log"
test -s "$HERE/work/coverage/rtl.json"
python3 "$HERE/scripts/summarize_coverage.py" "$HERE/work/coverage/rtl.json" \
    > "$HERE/work/coverage/summary.txt"
cat "$HERE/work/coverage/summary.txt"
