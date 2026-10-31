#!/usr/bin/env python3
"""Scan library testbenches for oracle functions that take a non-zero-based packed formal."""
import re
from pathlib import Path

TB = Path("design/ttl_74xx/tb")
func_re = re.compile(r"function\s+(?:automatic\s+)?(\w+)?\s*(\w+)\s*\((.*?)\)\s*;", re.S)
formal_re = re.compile(r"(?:input|ref|const\s+ref)?\s*(?:logic|bit|reg)?\s*(\[[^\]]*\])\s*(\w+)")

rows = []
for path in sorted(TB.glob("*.sv")):
    text = path.read_text(encoding="utf-8", errors="replace")
    has_loop = bool(re.search(r"\bfor\s*\(", text))
    zero_based_formals = 0
    nonzero_formals = 0
    examples = []
    for m in func_re.finditer(text):
        args = m.group(3)
        for fm in formal_re.finditer(args):
            rng = fm.group(1)
            name = fm.group(2)
            inner = rng.strip("[]")
            lo, _, hi = inner.partition(":")
            lo = lo.strip(); hi = hi.strip() if hi else lo
            if not hi.isdigit():
                continue
            low = min(int(lo), int(hi))
            if low == 0:
                zero_based_formals += 1
            else:
                nonzero_formals += 1
                examples.append(f"{m.group(2)}({name}{rng})")
    if nonzero_formals:
        rows.append((path.name, nonzero_formals, zero_based_formals, has_loop, examples[:3]))

print(f"testbenches scanned: {len(list(TB.glob('*.sv')))}")
print(f"testbenches with a non-zero-based packed formal: {len(rows)}")
for name, nz, z, loop, ex in rows:
    print(f"  {name:28} nonzero={nz} zero={z} for-loop={loop} {ex}")
