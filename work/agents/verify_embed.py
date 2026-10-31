#!/usr/bin/env python3
"""Check that the listing embedded in the report is identical to the file that was run."""
import re
import sys
from pathlib import Path

report = Path("work/agents/xezim-bug-report.md").read_text(encoding="utf-8")
source = Path("work/agents/xezim-repro/minimal_repro.sv").read_text(encoding="utf-8")

m = re.search(r"## Reproducer source.*?```systemverilog\n(.*?)```", report, re.S)
if not m:
    sys.exit("no systemverilog block found in the report")

embedded = m.group(1)
if embedded == source:
    print(f"OK: embedded listing is identical to the run file ({len(source)} bytes, "
          f"{source.count(chr(10))} lines)")
else:
    print("MISMATCH")
    a = embedded.splitlines()
    b = source.splitlines()
    for i in range(max(len(a), len(b))):
        x = a[i] if i < len(a) else "<missing>"
        y = b[i] if i < len(b) else "<missing>"
        if x != y:
            print(f"  line {i+1}:\n    report: {x!r}\n    file  : {y!r}")
            break
    sys.exit(1)
