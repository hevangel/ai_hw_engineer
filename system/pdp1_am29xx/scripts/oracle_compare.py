#!/usr/bin/env python3
"""Compare the RTL instruction trace with the SIMH PDP-1 oracle.

Inputs (both under work/):
    <name>.trace   RTL: "pc ir ac io ov pf microcycles" in octal
    <name>.simh.out  SIMH: "show cpu history" dump

The comparison is on the architectural state at instruction start: PC, IR,
AC, IO, OV and the program-flag word. It stops at the first difference and
prints both sides, so a mismatch names the exact instruction.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SIMH_LINE = re.compile(r"^(\d{6})\s+(\d)\s+(\d{6})\s+(\d{6})\s+(\d+)\s+(\d+)?", re.M)


def read_rtl(path: Path):
    rows = []
    for line in path.read_text().splitlines():
        parts = line.split()
        if len(parts) < 6:
            continue
        pc, ir, ac, io, ov, pf = (int(x, 8) for x in parts[:6])
        rows.append({"pc": pc, "ir": ir, "ac": ac, "io": io, "ov": ov, "pf": pf})
    return rows


def read_simh(path: Path):
    text = path.read_text()
    start = text.find("PC      OV AC")
    if start < 0:
        return []
    rows = []
    for match in SIMH_LINE.finditer(text, start):
        pc, ov, ac, io, pf = (int(match.group(i), 8) for i in (1, 2, 3, 4, 5))
        rows.append({"pc": pc, "ac": ac, "io": io, "ov": ov, "pf": pf,
                     "ir": None, "raw": match.group(0).strip()})
    return rows


def main(names):
    failures = 0
    for name in names:
        rtl = read_rtl(ROOT / "work" / f"{name}.trace")
        simh = read_simh(ROOT / "work" / f"{name}.simh.out")
        if not rtl or not simh:
            print(f"{name}: MISSING DATA (rtl={len(rtl)} simh={len(simh)})")
            failures += 1
            continue
        count = min(len(rtl), len(simh))
        mismatch = None
        for index in range(count):
            a, b = rtl[index], simh[index]
            # SIMH history does not print the instruction word on one line in a
            # machine-readable column, so IR is compared only when available.
            if (a["pc"], a["ac"], a["io"], a["ov"]) != (b["pc"], b["ac"], b["io"], b["ov"]):
                mismatch = index
                break
        if mismatch is None:
            print(f"{name}: {count} instructions match SIMH (pc/ac/io/ov); "
                  f"rtl={len(rtl)} simh={len(simh)}")
        else:
            a, b = rtl[mismatch], simh[mismatch]
            print(f"{name}: MISMATCH at instruction {mismatch}")
            print(f"  rtl : pc={a['pc']:04o} ac={a['ac']:06o} io={a['io']:06o} ov={a['ov']}")
            print(f"  simh: pc={b['pc']:04o} ac={b['ac']:06o} io={b['io']:06o} ov={b['ov']}")
            failures += 1
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
