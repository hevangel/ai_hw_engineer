#!/usr/bin/env python3
"""Cross-check the reference model's decoder against an independent
disassembler: A. Tarpai's listing of IBM 1503033, produced with his own
UPI-41/42 disassembler (external/halicery/8042, pinned in rebuild_1503033.py).

For every instruction line in the listing, the model must decode the same
bytes to the same mnemonic and length. Differences in notation only
(spacing, letter case, Tarpai's "OUTL P0,A"-style names for opcodes the
UPI-42 does not define) are listed explicitly in NOTATION below.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rebuild_1503033 import fetch_listing, parse_listing   # noqa: E402
from upi42_iss import disassemble                          # noqa: E402

INSN = re.compile(r'^\s*([0-9A-F]{4}): ((?:[0-9A-F]{2} ?){1,2})\s+([A-Z][^;]*?)\s*(?:;.*)?$')

# Tarpai spellings that differ from the model's for the same opcode.
NOTATION = {
    'JTO': 'JT0', 'JNTO': 'JNT0',
}


# Addresses where the listing decodes a data byte as an instruction.
# 7FEh-7FFh are the two bytes that zero the self-test CRC (the listing asks
# "what is this at the end of the ROM?"); 38h is not in UPI-42 Table 3-2.
DATA_BYTES = {0x7FF: ('OUTL P0,A', 'DB $38')}


def norm(s):
    s = s.upper().replace(' ', '').replace('\t', '')
    for k, v in NOTATION.items():
        s = s.replace(k, v)
    return s


def main():
    work = Path(sys.argv[1]) if len(sys.argv) > 1 else \
        Path(__file__).resolve().parents[1] / 'work'
    text, _ = fetch_listing(work / 'firmware' / '8042_1503033.TXT')
    mem = parse_listing(text)
    rom = bytes(mem.get(x, 0) for x in range(2048))
    checked = 0
    mismatches = []
    for line in text.splitlines():
        m = INSN.match(line)
        if not m:
            continue
        addr = int(m.group(1), 16)
        nbytes = len(m.group(2).split())
        theirs = m.group(3)
        ours, length = disassemble(rom, addr)
        checked += 1
        if addr in DATA_BYTES:
            if (theirs, ours) != DATA_BYTES[addr]:
                mismatches.append('%03X  data-byte exception changed: %s / %s' %
                                  (addr, theirs, ours))
            continue
        if length != nbytes or norm(ours) != norm(theirs):
            mismatches.append('%03X  listing: %-18s (%d)  model: %-18s (%d)' %
                              (addr, theirs, nbytes, ours, length))
    for x in mismatches:
        print('DIFF', x)
    print('checked %d instructions, %d differences' % (checked, len(mismatches)))
    return 1 if mismatches else 0


if __name__ == '__main__':
    sys.exit(main())
