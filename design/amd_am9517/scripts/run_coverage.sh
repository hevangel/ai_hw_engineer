#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/coverage"
echo "=== Am9517 RTL code coverage ==="
XEZIM_COV_DB="$HERE/work/coverage/rtl.json" \
xezim --simulate --sv2017 --error-exit --code-coverage \
    --code-coverage-scope tb_top.dut -s tb_top \
    "$HERE/src/amd_am9517.sv" "$HERE/tb/tb_top.sv" \
    --max-time 5000000ns -l "$HERE/work/coverage/sim.log"
grep 'Am9517 TEST PASSED' "$HERE/work/coverage/sim.log"
test -s "$HERE/work/coverage/rtl.json"
python3 "$HERE/scripts/summarize_coverage.py" "$HERE/work/coverage/rtl.json" \
    > "$HERE/work/coverage/summary.txt"
cat "$HERE/work/coverage/summary.txt"
