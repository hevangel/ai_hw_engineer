#!/usr/bin/env python3
"""Extend the provenance of the [N:1]-formal scan from functions to tasks.

The xezim defect is triggered by reading a packed formal whose declared range does
not start at zero. My first scan only inspected `function` declarations. Tasks take
formals too, so scan those, and report any task/function that both has such a formal
and indexes it with a variable.
"""
import re
from pathlib import Path

TB = Path("design/ttl_74xx/tb")
decl_re = re.compile(r"\b(function|task)\b([^;]*?)\((.*?)\)\s*;", re.S)
formal_re = re.compile(r"(?:input|output|inout|ref|const\s+ref)?\s*(?:logic|bit|reg|wire)?\s*(\[[^\]]*\])?\s*(\w+)")

def nonzero_range(rng):
    if not rng:
        return None
    inner = rng.strip("[]")
    lo, _, hi = inner.partition(":")
    lo = lo.strip()
    hi = hi.strip() if hi else lo
    if not (lo.isdigit() and hi.isdigit()):
        return None
    low, high = sorted((int(lo), int(hi)))
    if low == 0:
        return None
    return f"[{high}:{low}]" if low == high - (max(int(lo),int(hi))-min(int(lo),int(hi))) else rng


hits = []
for path in sorted(TB.glob("*.sv")):
    text = path.read_text(encoding="utf-8", errors="replace")
    for m in decl_re.finditer(text):
        kind = m.group(1)
        name = (m.group(2) or "").split()[-1] if (m.group(2) or "").split() else "?"
        args = m.group(3)
        for fm in formal_re.finditer(args):
            rng, arg = fm.group(1), fm.group(2)
            if not rng:
                continue
            inner = rng.strip("[]")
            lo, _, hi = inner.partition(":")
            lo = lo.strip(); hi = hi.strip() if hi else lo
            if not (lo.isdigit() and hi.isdigit()):
                continue
            if min(int(lo), int(hi)) == 0:
                continue
            # does the body index this formal with something other than a constant?
            body = text[m.end():m.end() + 4000]
            var_index = re.search(rf"\b{re.escape(arg)}\s*\[\s*[A-Za-z_]\w*\s*\]", body)
            hits.append((path.name, kind, name, arg, rng, bool(var_index)))

print(f"scanned: {len(list(TB.glob('*.sv')))} testbenches")
print(f"subroutines with a non-zero-based packed formal: {len(hits)}")
for row in hits:
    print("  ", row)
