#!/usr/bin/env python3
"""Compare a 65,536-word PLA dump with a map derived from unchanged VICE.

The CPU map comes from the read tables and write hooks VICE builds for its
32 memory configurations (c64mem.c, c64meminit.c); the VIC map from the
character-ROM address options (c64mem.c) and the Ultimax ROMH window
(vicii.c). VICE models neither BA, CAS nor the GR/W strobe; those inputs are
handled as stated in spec/spec.md and counted separately.
"""
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parents[1]
VICE = HERE / "work/vice"
OUT = ["casram", "basic", "kernal", "charom", "grw", "io", "roml", "romh"]


def ints(text):
    return [int(v, 0) for v in re.findall(r"0x[0-9a-fA-F]+|\d+", text)]


def array(source, name):
    match = re.search(rf"{name}\[32\]\s*=\s*\{{([^}}]*)\}}", source)
    if not match:
        raise SystemExit(f"VICE table {name} not found")
    values = ints(match.group(1))
    assert len(values) == 32, name
    return values


def configs(source, pattern):
    found = {int(v) for v in re.findall(pattern, source)}
    if not found:
        raise SystemExit(f"no VICE configurations for {pattern}")
    return found


def load():
    mem = (VICE / "c64mem.c").read_text()
    init = (VICE / "c64meminit.c").read_text()
    vicii = (VICE / "vicii.c").read_text()
    t = {
        "io": array(init, "c64meminit_io_config"),
        "roml": array(init, "c64meminit_roml_config"),
        "romh": array(init, "c64meminit_romh_config"),
        "romh_map": array(init, "c64meminit_romh_mapping"),
        "chargen": configs(mem, r"mem_read_tab\[(\d+)\]\[i\] = chargen_read;"),
        "basic": configs(init, r"mem_read_tab_set\(base \+ (\d+), i, c64memrom_basic64_read\)"),
        "kernal": configs(init, r"mem_read_tab_set\(base \+ (\d+), i, c64memrom_kernal64_read\)"),
    }
    # Ultimax CPU holes: every page range given an ultimax_XXXX_YYYY_read handler.
    holes = set()
    for lo, hi, handler in re.findall(
            r"for \(i = (0x[0-9a-f]+); i <= (0x[0-9a-f]+); i\+\+\) \{\s*"
            r"mem_read_tab_set\(base \+ j, i, (ultimax_[0-9a-f]+_[0-9a-f]+)_read\)", init):
        # $D000-$DFFF is Ultimax I/O; $0800-$0FFF holes apply only to BOARD_MAX.
        if handler != "ultimax_d000_dfff" and int(lo, 16) >= 0x10:
            holes.update(range(int(lo, 16) >> 4, (int(hi, 16) >> 4) + 1))
    t["holes"] = holes
    # VIC character ROM window, e.g. vicii_set_chargen_addr_options(0x7000, 0x1000).
    m = re.search(r"vicii_set_chargen_addr_options\((0x[0-9a-f]+), (0x[0-9a-f]+)\)", mem)
    t["chr_mask"], t["chr_value"] = int(m.group(1), 16), int(m.group(2), 16)
    # Ultimax VIC ROMH window: (screen_addr & 0x3fff) >= 0x3000.
    m = re.search(r"\(screen_addr & 0x3fff\) >= (0x[0-9a-f]+)", vicii)
    t["umax_vic_base"] = int(m.group(1), 16)
    assert t["holes"] == {1, 2, 3, 4, 5, 6, 7, 0xa, 0xb, 0xc}, sorted(t["holes"])
    return t


def expected(word, t):
    """Return (set of asserted outputs, category) or None if out of scope."""
    bit = lambda n: (word >> n) & 1
    cas, loram, hiram, charen, va14 = (bit(i) for i in range(5))
    a15, a14, a13, a12, ba, aec, rw, exrom, game, va13, va12 = (bit(i) for i in range(5, 16))
    if cas:
        return None  # CAS-high words are checked against CAS-low ones (spec 4.4)
    ultimax = exrom and not game
    sel = set()
    if aec:  # VIC cycle: VA15 = !PA1 does not reach the PLA, VA14 = !va14
        vaddr = ((not va14) << 14) | (va13 << 13) | (va12 << 12)
        if ultimax:
            if vaddr & 0x3000 >= t["umax_vic_base"]:
                sel.add("romh")
        elif (vaddr & t["chr_mask"]) == t["chr_value"]:
            sel.add("charom")
        if not sel:
            sel.add("casram")
        return sel, "vic"
    cfg = ((not game) << 4) | ((not exrom) << 3) | (charen << 2) | (hiram << 1) | loram
    page = (a15 << 3) | (a14 << 2) | (a13 << 1) | a12
    if page == 0xd and not rw:
        sel.add("grw")  # C64 schematic: color RAM R/W for CPU writes at $Dxxx
    io = page == 0xd and t["io"][cfg] != 0
    if rw:
        if io and not ba:
            return None  # BA-gated I/O reads: not modeled by VICE (spec 4.3)
        if io:
            sel.add("io")
        elif page == 0xd and cfg in t["chargen"]:
            sel.add("charom")
        elif page in (0xa, 0xb) and cfg in t["basic"]:
            sel.add("basic")
        elif page in (0xe, 0xf) and cfg in t["kernal"]:
            sel.add("kernal")
        elif page in (8, 9) and t["roml"][cfg]:
            sel.add("roml")
        elif t["romh"][cfg] and t["romh_map"][cfg] >> 4 <= page <= (t["romh_map"][cfg] + 0x1f) >> 4:
            sel.add("romh")
        elif ultimax and page in t["holes"]:
            pass
        else:
            sel.add("casram")
        return sel, "cpu-read"
    # Writes: I/O, Ultimax cartridge windows (roml_store/romh_store) and
    # holes; everything else writes through to DRAM.
    if io:
        sel.add("io")
    elif ultimax and page in (8, 9):
        sel.add("roml")
    elif ultimax and page in (0xe, 0xf):
        sel.add("romh")
    elif ultimax and page in t["holes"]:
        pass
    else:
        sel.add("casram")
    return sel, "cpu-write"


def main():
    t = load()
    dumps = sys.argv[1:]
    if not dumps:
        raise SystemExit("usage: pla_oracle.py DUMP [DUMP...]")
    for dump in dumps:
        lines = Path(dump).read_text().split()
        if len(lines) != 65536:
            raise SystemExit(f"{dump}: expected 65536 words, got {len(lines)}")
        got = [int(v, 16) for v in lines]
        counts, failures = {}, []
        for word in range(65536):
            asserted = {OUT[b] for b in range(8) if not (got[word] >> b) & 1}
            exp = expected(word, t)
            if exp is None:
                continue
            sel, category = exp
            counts[category] = counts.get(category, 0) + 1
            if asserted != sel:
                failures.append((word, sorted(sel), sorted(asserted)))
        # Out-of-scope classes, checked against stated rules (spec 4.3/4.4).
        cas_checked = ba_checked = 0
        for word in range(65536):
            if word & 1:
                low = got[word & ~1]
                want = (low | 0x01 | 0x10)  # CAS high: CASRAM and GR/W idle
                if got[word] != want:
                    failures.append((word, f"{want:02x}", f"{got[word]:02x}"))
                cas_checked += 1
        for word in range(65536):
            if word & 1 or (word >> 10) & 1 or not (word >> 11) & 1 or (word >> 9) & 1:
                continue
            page = (((word >> 5) & 1) << 3) | (((word >> 6) & 1) << 2) | (((word >> 7) & 1) << 1) | ((word >> 8) & 1)
            if t["io"][((not (word >> 13) & 1) << 4) | ((not (word >> 12) & 1) << 3) | ((word >> 1) & 7)] and page == 0xd:
                # BA low read in I/O: no chip selected, DRAM read instead.
                if got[word] != 0xfe:
                    failures.append((word, "fe", f"{got[word]:02x}"))
                ba_checked += 1
        if failures:
            for word, want, have in failures[:20]:
                print(f"MISMATCH word {word:04x}: expected {want} got {have}")
            raise SystemExit(f"{dump}: {len(failures)} mismatches")
        total = sum(counts.values())
        print(f"{dump}: PASS {total} VICE-mapped words "
              f"({', '.join(f'{k} {v}' for k, v in sorted(counts.items()))}); "
              f"{cas_checked} CAS-high and {ba_checked} BA-low I/O-read words per spec")


if __name__ == "__main__":
    main()
