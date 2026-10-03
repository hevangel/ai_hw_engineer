#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/coverage"
XEZIM_COV_DB="$HERE/work/coverage/rtl.json" xezim --simulate --sv2017 --error-exit --code-coverage --code-coverage-scope tb_top.dut -s tb_top "$HERE/src/intel_8275.sv" "$HERE/tb/tb_top.sv" +seed=2026 +vectors="$HERE/references/graphics_vectors.hex" > "$HERE/work/coverage/run.log" 2>&1
grep '8275 PIN SUITE PASSED' "$HERE/work/coverage/run.log"
python3 "$HERE/scripts/summarize_coverage.py" "$HERE/work/coverage/rtl.json"
