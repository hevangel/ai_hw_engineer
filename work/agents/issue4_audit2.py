#!/usr/bin/env python3
"""Read-only audit: historical dates and spec coverage for the 74-series library."""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TTL = ROOT / "design" / "ttl_74xx"
entries = json.loads((TTL / "manifest.json").read_text())

print("== representative sub-issue functions in the normalized library ==")
by_part = {e["part_number"]: e for e in entries}
for pn in ("74x00", "74x02", "74x04", "74x08", "74x11", "74x138", "74x139",
           "74x151", "74x153", "74x161", "74x166", "74x174", "74x175",
           "74x194", "74x195", "74x20", "74x251", "74x257", "74x259",
           "74x283", "74x32", "74x74", "74x86", "74x181"):
    e = by_part.get(pn)
    print(f"{pn:8} {e['status'] if e else 'MISSING':11} {e['description'][:60] if e else ''}")

impl = [e for e in entries if e["status"] == "implemented"]
null_year = [e for e in impl if not e.get("introduction_year")]
print(f"\n== historical dates ==\nimplemented={len(impl)}  null introduction_year={len(null_year)}")

print("\n== spec file presence ==")
spec_dir = TTL / "spec" / "chips"
specs = {p.stem for p in spec_dir.glob("*.md")} if spec_dir.is_dir() else set()
print(f"spec/chips/*.md files: {len(specs)}")
declared = {Path(e["specification"]).stem for e in impl}
print(f"declared but missing: {len(declared - specs)}")
print(f"present but undeclared: {len(specs - declared)}")
print("examples missing:", sorted(declared - specs)[:10])

print("\n== rtl/tb counts ==")
print("src/*.sv:", len(list((TTL / 'src').glob('*.sv'))))
print("tb/*.sv:", len(list((TTL / 'tb').glob('*.sv'))))
