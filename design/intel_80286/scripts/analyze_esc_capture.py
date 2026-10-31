#!/usr/bin/env python3
"""Check D8 command writes against independently captured 286 bus cycles.

This is an evidence extractor, not an 80287 model or a CPU regression. Supply
the revision-pinned D8.MOO.gz and revocation list described in the report.
"""
import argparse
from collections import Counter
import gzip
import hashlib
from pathlib import Path
import struct

from hardware_moo import _chunk, parse_moo

CAPTURE_SHA256 = '4fb3540180b6d30e9eb3cb958c6ff81f5be6bb4aac588d682f2dda82b7a3dc4d'
REVOCATION_GIT_BLOB = 'b589c24fa5316cad0899e8ceff310ab6f7f38991'
CYCLE = struct.Struct('<B I B B B B H B B B B')
SEGMENTS = {0x26: 'es', 0x2e: 'cs', 0x36: 'ss', 0x3e: 'ds'}
PREFIXES = set(SEGMENTS) | {0xf0, 0xf2, 0xf3}


def cycle_records(data):
    pos = 8 + int.from_bytes(data[4:8], 'little')
    records = {}
    while pos < len(data):
        tag, start, end = _chunk(data, pos, len(data), 'MOO')
        if tag == 'TEST':
            idx = int.from_bytes(data[start:start + 4], 'little')
            sub = start + 4
            while sub < end:
                name, first, last = _chunk(data, sub, end, 'TEST')
                if name == 'CYCL':
                    count = int.from_bytes(data[first:first + 4], 'little')
                    records[idx] = [CYCLE.unpack_from(data, first + 4 + i * CYCLE.size)
                                    for i in range(count)]
                sub = last
        pos = end
    return records


def writes(cycles):
    result = []
    for i, c in enumerate(cycles):
        # The data during Ts is stale. Pair the IOW status and its next Tc
        # completion; the address on Tc may already be pipelined.
        if c[7] & 15 == 10 and c[8] & 7 == 1:
            if i + 1 == len(cycles):
                raise ValueError('IOW status has no following data phase')
            d = cycles[i + 1]
            if d[8] & 7 != 2 or d[4] != 1 or c[0] & 2:
                raise ValueError('unexpected IOW completion or non-word lane')
            result.append((c[1], d[6]))
    return result


def expected(test):
    code = test['bytes']
    i = 0
    segment = None
    while i < len(code) and code[i] in PREFIXES:
        if code[i] in SEGMENTS:
            segment = SEGMENTS[code[i]]
        i += 1
    if i + 2 >= len(code) or code[i] != 0xd8 or code[-1] != 0xf4:
        raise ValueError('unexpected D8 encoding')
    modrm = code[i + 1]
    mod, rm = modrm >> 6, modrm & 7
    regs = test['initial']['regs']
    result = [(0xf8, (modrm << 8) | 0xd8), (0xfc, regs['ip']), (0xfc, regs['cs'])]
    if mod != 3:
        forms = (('bx', 'si'), ('bx', 'di'), ('bp', 'si'), ('bp', 'di'),
                 ('si',), ('di',), ('bp',), ('bx',))
        direct = mod == 0 and rm == 6
        disp_size = 2 if direct or mod == 2 else (1 if mod == 1 else 0)
        if len(code) != i + 3 + disp_size:
            raise ValueError('unexpected displacement length')
        disp = int.from_bytes(bytes(code[i + 2:i + 2 + disp_size]), 'little',
                              signed=bool(disp_size and not direct))
        terms = () if direct else forms[rm]
        offset = (disp + sum(regs[r] for r in terms)) & 0xffff
        selected = segment or ('ss' if 'bp' in terms else 'ds')
        result.extend(((0xfc, offset), (0xfc, regs[selected])))
    elif len(code) != i + 3:
        raise ValueError('unexpected register encoding length')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('revocations', type=Path)
    args = parser.parse_args()
    raw = args.capture.read_bytes()
    if hashlib.sha256(raw).hexdigest() != CAPTURE_SHA256:
        raise ValueError('capture does not match pinned SHA-256')
    rev = args.revocations.read_bytes()
    blob = b'blob ' + str(len(rev)).encode() + b'\0' + rev
    if hashlib.sha1(blob).hexdigest() != REVOCATION_GIT_BLOB:
        raise ValueError('revocation list does not match pinned Git blob')
    revoked = {line.strip().lower() for line in rev.decode('ascii').splitlines()
               if line and not line.startswith('#')}
    data = gzip.decompress(raw)
    tests = parse_moo(data)['tests']
    cycles = cycle_records(data)
    counts = Counter()
    for test in tests:
        if test['hash'] in revoked:
            counts['revoked'] += 1
            continue
        actual = writes(cycles[test['idx']])
        if 'exception' in test:
            if actual:
                raise ValueError(f"exception emitted writes: {test['hash']}")
            counts[f"exception_{test['exception']['number']}"] += 1
            continue
        want = expected(test)
        if actual != want:
            raise ValueError(f"{test['hash']}: expected {want!r}, captured {actual!r}")
        counts['register' if len(want) == 3 else 'memory'] += 1
    print(f'Capture SHA-256: {CAPTURE_SHA256}')
    print('Counts:', dict(sorted(counts.items())))
    print('PASS: all non-revoked captured transactions match the checked D8 contract')


if __name__ == '__main__':
    main()
