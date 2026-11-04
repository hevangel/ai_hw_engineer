#!/usr/bin/env python3
"""Evidence check for assumption A39: compare IDIV division models with physical
Harris-286 F6.7/F7.7 captures. Usage: analyze_idiv_captures.py <MOO.gz>.
The 'noprecheck w8' row is the model the RTL implements.
"""
import gzip, sys
from collections import Counter
from pathlib import Path
sys.path.insert(0, 'scripts')
from hardware_moo import parse_moo
REG16 = ('ax', 'cx', 'dx', 'bx', 'sp', 'bp', 'si', 'di')
EA = {0: ('bx', 'si'), 1: ('bx', 'di'), 2: ('bp', 'si'), 3: ('bp', 'di'), 4: ('si',), 5: ('di',), 6: ('bp',), 7: ('bx',)}


def s(v, bits):
    return v - (1 << bits) if v >> (bits - 1) else v


def records(path, wide):
    for t in parse_moo(gzip.decompress(Path(path).read_bytes()))['tests']:
        b = t['bytes']; i = 0
        while b[i] in (0x26, 0x2e, 0x36, 0x3e, 0xf0, 0xf2, 0xf3): i += 1
        pfx = [x for x in b[:i] if x in (0x26, 0x2e, 0x36, 0x3e)]
        m = b[i + 1]; mod, rm = m >> 6, m & 7
        ini = t['initial']['regs']; fin = {**ini, **t['final']['regs']}
        ram = dict(t['initial']['ram'])
        if mod == 3:
            d = ini[REG16[rm]] if wide else ((ini[('ax', 'cx', 'dx', 'bx')[rm & 3]] >> (8 if rm >= 4 else 0)) & 0xff)
        else:
            disp = 0
            if mod == 1: disp = s(b[i + 2], 8)
            elif mod == 2 or (mod == 0 and rm == 6): disp = b[i + 2] | b[i + 3] << 8
            off = (disp + sum(ini[r] for r in (EA[rm] if not (mod == 0 and rm == 6) else ()))) & 0xffff
            seg = 'ss' if rm in (2, 3) or (rm == 6 and mod != 0) else 'ds'
            if pfx: seg = {0x26: 'es', 0x2e: 'cs', 0x36: 'ss', 0x3e: 'ds'}[pfx[-1]]
            a = ini[seg] * 16 + off
            if wide and off == 0xffff:
                continue
            d = ram.get(a, 0) | ((ram.get(a + 1, 0) << 8) if wide else 0)
        n = (ini['dx'] << 16 | ini['ax']) if wide else ini['ax']
        yield n, d, bool(t.get('exception')), fin


def model(n, d, bits):
    """Candidate: magnitudes, unsigned restoring loop with (bits+1)-bit remainder."""
    sn, sd = s(n, 2 * bits), s(d, bits)
    if sd == 0:
        return 'fault'
    mn, md = abs(sn), abs(sd)
    mask = (1 << bits) - 1
    hi, lo = mn >> bits, mn & mask
    if hi >= md and VARIANT == 'precheck':
        return 'fault'
    rem, q = hi, 0
    width = {'w8': bits, 'w9': bits + 1, 'winf': 64}[WIDTH]
    for i in range(bits - 1, -1, -1):
        rem = ((rem << 1) | ((lo >> i) & 1)) & ((1 << width) - 1)
        q <<= 1
        if rem >= md:
            rem -= md; q |= 1
    if QMASK:
        q &= mask
    neg = (sn < 0) != (sd < 0)
    if neg:
        if q > (1 << (bits - 1)):
            return 'fault'
        q = (-q) & mask
    elif q > (1 << (bits - 1)) - 1:
        return 'fault'
    r = (-rem if sn < 0 else rem) & mask
    return q | r << bits


bits = 16 if 'F7' in sys.argv[1] else 8
recs = list(records(sys.argv[1], bits == 16))
for VARIANT in ('precheck', 'noprecheck'):
    for WIDTH in ('w8', 'w9', 'winf'):
        for QMASK in (True, False):
            c = Counter(); bad = []
            for n, d, exc, fin in recs:
                r = model(n, d, bits)
                if exc:
                    c['ok' if r == 'fault' else 'miss-fault'] += 1
                else:
                    got = fin['ax'] if bits == 8 else (fin['dx'] << 16 | fin['ax'])
                    c['ok' if r == got else 'miss-val'] += 1
                    if r != got and len(bad) < 4: bad.append((hex(n), hex(d), r if r == 'fault' else hex(r), hex(got)))
            print(VARIANT, WIDTH, QMASK, dict(c), bad)
