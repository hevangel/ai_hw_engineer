#!/usr/bin/env python3
"""Read-only audit: characterise the 165 pending parts by functional family."""
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TTL = ROOT / "design" / "ttl_74xx"
entries = json.loads((TTL / "manifest.json").read_text())
by_part = {e["part_number"]: e for e in entries}

pending = [e for e in entries if e["status"] == "pending"]

def base_of(pn):
    """Strip vendor/family prefix variants: 74x8244 -> 74x244, 74LS244 -> 74x244."""
    m = re.fullmatch(r"74(?:x|LS|L|H|S|ALS|F|C|HC|HCT|ABT|ACT|BCT|FCT|AHC|LV|LVC)?(\d+)", pn)
    return m.group(1) if m else None

print("== pending parts: does a same-function implemented base exist? ==")
same_fn = []
for e in pending:
    digits = base_of(e["part_number"])
    if not digits:
        continue
    for cand in (f"74x{digits}", f"74{digits}"):
        b = by_part.get(cand)
        if b and b["status"] == "implemented":
            same_fn.append((e, b))
            break

for e, b in same_fn:
    print(f"{e['part_number']:10} <-> {b['part_number']:8} desc_equal={e['description']==b['description']}")
    if e["description"] != b["description"]:
        print(f"           pending: {e['description'][:70]}")
        print(f"           base   : {b['description'][:70]}")
print(f"\ncount with implemented numeric base: {len(same_fn)} / {len(pending)}")

print("\n== pending: source_section / model_level mix ==")
mix = defaultdict(int)
for e in pending:
    mix[(e.get("source_section"), e.get("model_level"))] += 1
for k, v in sorted(mix.items(), key=lambda x: -x[1]):
    print(k, v)

print("\n== pending parts sorted, with one-line reason ==")
for e in pending:
    print(f"{e['part_number']:12} {e['description'][:52]:54} {e.get('reason','')[:60]}")
