#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/coverage"
XEZIM_COV_DB="$HERE/work/coverage/rtl.json" xezim --simulate --sv2017 --error-exit --code-coverage --code-coverage-scope tb_top.dut -I "$HERE/tb" -s tb_top "$HERE"/src/*.sv "$HERE/tb/intel_8273_if.sv" "$HERE/tb/tb_top.sv" +vectors="$HERE/references/frames.txt" > "$HERE/work/coverage/run.log" 2>&1
grep '8273 SUITE PASSED' "$HERE/work/coverage/run.log"
python3 "$HERE/scripts/summarize_coverage.py" "$HERE/work/coverage/rtl.json"
echo '8273 COVERAGE PASSED'
