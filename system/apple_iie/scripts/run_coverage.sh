#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test -s work/coverage.dat
verilator_coverage --write-info work/coverage.info work/coverage.dat
python3 - <<'PY'
from pathlib import Path
import json
records=[line.split(',') for line in Path('work/coverage.info').read_text().splitlines() if line.startswith('DA:')]
covered=sum(int(row[1])>0 for row in records)
summary={'covered_lines':covered,'total_lines':len(records),'percent':round(100*covered/len(records),2)}
Path('work/coverage_summary.json').write_text(json.dumps(summary))
print('PASS IIe real-firmware RTL line coverage:',summary)
PY
