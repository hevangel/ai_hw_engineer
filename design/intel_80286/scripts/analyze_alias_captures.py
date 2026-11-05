#!/usr/bin/env python3
"""Survey physical-286 captures for undocumented opcode aliases.

Evidence extractor only. For register-form shift /6 (C0/C1/D0-D3), compare
captured results with SHL (/4) computed here; for 82 /n compare with the 80 /n
group ALU; for D6 check AL against CF. Prints counts and first mismatches.
"""
import argparse
from collections import Counter
import gzip
from pathlib import Path

from hardware_moo import parse_moo

PREFIXES = {0x26, 0x2e, 0x36, 0x3e, 0xf0, 0xf2, 0xf3}
REG8 = ('al', 'cl', 'dl', 'bl', 'ah', 'ch', 'dh', 'bh')
REG16 = ('ax', 'cx', 'dx', 'bx', 'sp', 'bp', 'si', 'di')
CF, PF, AF, ZF, SF, OF = 0x1, 0x4, 0x10, 0x40, 0x80, 0x800


def get8(regs, n):
    word = regs[('ax', 'cx', 'dx', 'bx')[n & 3]]
    return (word >> 8) & 0xff if n >= 4 else word & 0xff


def parity(v):
    return 0 if bin(v & 0xff).count('1') & 1 else PF


def szp(v, width):
    mask = (1 << width) - 1
    v &= mask
    f = parity(v)
    if v == 0:
        f |= ZF
    if v >> (width - 1):
        f |= SF
    return f


def shl(value, count, width, flags):
    """Repeated 80286 SHL (count masked to 5 bits); returns (result, flags, defined mask)."""
    count &= 0x1f
    if count == 0:
        return value, flags, 0
    mask = (1 << width) - 1
    v = value & mask
    cf = 0
    for _ in range(count):
        cf = (v >> (width - 1)) & 1
        v = (v << 1) & mask
    f = szp(v, width) | (CF if cf else 0)
    defined = CF | PF | ZF | SF
    if count == 1:
        if ((v >> (width - 1)) & 1) != cf:
            f |= OF
        defined |= OF
    return v, f, defined


def alu(op, a, b, width, flags):
    mask = (1 << width) - 1
    cin = flags & CF
    if op in (0, 2):  # ADD/ADC
        c = cin if op == 2 else 0
        r = a + b + c
        res = r & mask
        f = szp(res, width) | (CF if r >> width else 0)
        if ((a ^ b ^ res) & 0x10):
            f |= AF
        if (~(a ^ b) & (a ^ res)) >> (width - 1) & 1:
            f |= OF
        return res, f, CF | PF | AF | ZF | SF | OF, True
    if op in (3, 5, 7):  # SBB/SUB/CMP
        c = cin if op == 3 else 0
        r = a - b - c
        res = r & mask
        f = szp(res, width) | (CF if r < 0 else 0)
        if ((a ^ b ^ res) & 0x10):
            f |= AF
        if ((a ^ b) & (a ^ res)) >> (width - 1) & 1:
            f |= OF
        return res, f, CF | PF | AF | ZF | SF | OF, op != 7
    r = {1: a | b, 4: a & b, 6: a ^ b}[op]
    return r, szp(r, width), CF | PF | ZF | SF | OF, True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path, nargs='+')
    args = parser.parse_args()
    for path in args.captures:
        tests = parse_moo(gzip.decompress(path.read_bytes()))['tests']
        counts = Counter()
        mismatches = []
        for test in tests:
            code = test['bytes']
            i = 0
            while i < len(code) and code[i] in PREFIXES:
                i += 1
            op = code[i]
            init = test['initial']['regs']
            fin = {**init, **test['final']['regs']}
            if 'exception' in test:
                counts[f"exception_{test['exception']['number']}"] += 1
                continue
            if op == 0xd6:
                want = 0xff if init['flags'] & CF else 0x00
                ok = (fin['ax'] & 0xff) == want and (fin['ax'] >> 8) == (init['ax'] >> 8)
                counts['match' if ok else 'mismatch'] += 1
                if not ok and len(mismatches) < 5:
                    mismatches.append((bytes(code).hex(), hex(init['ax']), hex(init['flags']), hex(fin['ax'])))
                continue
            modrm = code[i + 1]
            if modrm >> 6 != 3:
                counts['memory_form_skipped'] += 1
                continue
            reg, rm = (modrm >> 3) & 7, modrm & 7
            wide = op & 1
            width = 16 if wide else 8
            src = init[REG16[rm]] if wide else get8(init, rm)
            if op in (0xc0, 0xc1, 0xd0, 0xd1, 0xd2, 0xd3):
                count = (1 if op in (0xd0, 0xd1) else
                         init['cx'] & 0xff if op in (0xd2, 0xd3) else code[i + 2])
                res, f, defined = shl(src, count, width, init['flags'])
                write = True
            else:  # 82 /n: byte group ALU with imm8
                res, f, defined, write = alu(reg, src, code[i + 2], 8, init['flags'])
            got = fin[REG16[rm]] if wide else get8(fin, rm)
            ok = (not write or got == res) and (fin['flags'] & defined) == (f & defined)
            counts['match' if ok else 'mismatch'] += 1
            if not ok and len(mismatches) < 5:
                mismatches.append((bytes(code).hex(), hex(src), hex(init['flags']),
                                   hex(got), hex(res), hex(fin['flags']), hex(f), hex(defined)))
        print(f'== {path.name}: {dict(sorted(counts.items()))}')
        for m in mismatches:
            print('  MISMATCH', m)


if __name__ == '__main__':
    main()
