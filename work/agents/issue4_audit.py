#!/usr/bin/env python3
"""Read-only audit helper for hevangel/ai_engineer issue #4 (74-series family)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TTL = ROOT / "design" / "ttl_74xx"

entries = json.loads((TTL / "manifest.json").read_text())
by_part = {e["part_number"]: e for e in entries}
alias = {}
for e in entries:
    for a in e.get("aliases", []):
        alias[a] = e

SUB_ISSUE_PARTS = [
    "74181", "74LS00", "74LS02", "74LS04", "74LS08", "74LS11", "74LS138",
    "74LS139", "74LS151", "74LS153", "74LS161", "74LS166", "74LS174",
    "74LS175", "74LS194", "74LS195", "74LS20", "74LS251", "74LS257",
    "74LS259", "74LS283", "74LS32", "74LS51", "74LS74", "74LS86",
]

print("== 25 sub-issue parts mapped onto the normalized library ==")
missing = []
for want in SUB_ISSUE_PARTS:
    e = by_part.get(want) or alias.get(want)
    if e:
        print(f"{want:8} -> {e['part_number']:8} {e['status']:11} {e['module']}")
    else:
        missing.append(want)
        print(f"{want:8} -> NOT IN MANIFEST")
print(f"\nunmapped: {missing or 'none'}")

print("\n== status totals ==")
from collections import Counter
print(Counter(e["status"] for e in entries), "total", len(entries))

print("\n== pending parts by source_section ==")
print(Counter(e.get("source_section", "?") for e in entries if e["status"] == "pending"))

print("\n== parts whose modules are aliased duplicates of implemented bases ==")
# parts that exist only as a pending prefixed variant of an implemented base
for e in entries:
    if e["status"] != "pending":
        continue
    pn = e["part_number"]
    digits = pn.split("LS")[-1].split("S")[-1]
    for cand in ("74x" + digits, "74" + digits):
        base = by_part.get(cand)
        if base and base["status"] == "implemented" and base["part_number"] != pn:
            print(f"{pn:10} base {base['part_number']:8} same-desc={base['description'] == e['description']}")
            break
