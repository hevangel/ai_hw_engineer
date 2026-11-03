#!/usr/bin/env python3
"""Survey ESC (D8-DF) command writes in pinned physical-286 captures.

Evidence extractor only, not an 80287 model. For each supplied
<opcode>.MOO.gz, compare the captured IOW words with the D8 contract from
report/2026-10-30-d8-physical-command.md generalized to the capture's opcode,
classify exception cases and tally bus status types.
"""
import argparse
from collections import Counter
import gzip
import hashlib
from pathlib import Path

from analyze_esc_capture import PREFIXES, SEGMENTS, cycle_records, writes
from hardware_moo import parse_moo

FORMS = (('bx', 'si'), ('bx', 'di'), ('bp', 'si'), ('bp', 'di'),
         ('si',), ('di',), ('bp',), ('bx',))


def decode(test):
    code = test['bytes']
    i = 0
    segment = None
    while i < len(code) and code[i] in PREFIXES:
        if code[i] in SEGMENTS:
            segment = SEGMENTS[code[i]]
        i += 1
    opcode, modrm = code[i], code[i + 1]
    mod, rm = modrm >> 6, modrm & 7
    regs = test['initial']['regs']
    offset = selected = None
    if mod != 3:
        direct = mod == 0 and rm == 6
        size = 2 if direct or mod == 2 else (1 if mod == 1 else 0)
        disp = int.from_bytes(bytes(code[i + 2:i + 2 + size]), 'little',
                              signed=bool(size and not direct))
        terms = () if direct else FORMS[rm]
        offset = (disp + sum(regs[r] for r in terms)) & 0xffff
        selected = segment or ('ss' if 'bp' in terms else 'ds')
    return opcode, modrm, offset, selected, i


def expected(test):
    opcode, modrm, offset, selected, _ = decode(test)
    regs = test['initial']['regs']
    result = [(0xf8, (modrm << 8) | opcode), (0xfc, regs['ip']), (0xfc, regs['cs'])]
    if offset is not None:
        result.extend(((0xfc, offset), (0xfc, regs[selected])))
    return result


def status_types(cycles):
    return Counter(c[7] & 15 for c in cycles if c[8] & 7 == 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('revocations', type=Path)
    parser.add_argument('captures', type=Path, nargs='+')
    args = parser.parse_args()
    rev = args.revocations.read_bytes().decode('ascii')
    revoked = {line.strip().lower() for line in rev.splitlines()
               if line and not line.startswith('#')}
    for path in args.captures:
        raw = path.read_bytes()
        data = gzip.decompress(raw)
        tests = parse_moo(data)['tests']
        cycles = cycle_records(data)
        counts, statuses, exceptions, other_io = Counter(), Counter(), Counter(), Counter()
        mismatches = []
        for test in tests:
            if test['hash'] in revoked:
                counts['revoked'] += 1
                continue
            cyc = cycles[test['idx']]
            statuses.update(status_types(cyc))
            actual = writes(cyc)
            opcode, modrm, offset, _, prefix_len = decode(test)
            if 'exception' in test:
                length = len(test['bytes']) - 1  # trailing HLT
                key = (test['exception']['number'], 'len>10' if length > 10 else f'len={length}',
                       'mem' if offset is not None else 'reg',
                       'off=FFFF' if offset == 0xffff else ('off>=FFFB' if offset is not None and offset >= 0xfffb else 'off<FFFB'))
                exceptions[key] += 1
                if actual:
                    counts['exception_with_writes'] += 1
                continue
            want = expected(test)
            ports = Counter(p for p, _ in actual)
            for p in ports:
                if p not in (0xf8, 0xfc):
                    other_io[p] += ports[p]
            if actual != want:
                counts['mismatch'] += 1
                if len(mismatches) < 5:
                    mismatches.append((test['hash'], test['bytes'], want, actual))
            else:
                counts['register' if offset is None else 'memory'] += 1
            ip0, ip1 = test['initial']['regs']['ip'], test['final']['regs']['ip']
            counts['retires_to_hlt+1' if ip1 == ((ip0 + len(test['bytes'])) & 0xffff) else 'other_final_ip'] += 1
        print(f'== {path.name} sha256={hashlib.sha256(raw).hexdigest()}')
        print('counts:', dict(sorted(counts.items())))
        print('status types (status-phase low nibble):', dict(sorted(statuses.items())))
        print('other IOW ports:', dict(other_io))
        for key, n in sorted(exceptions.items()):
            print('exception', key, n)
        for m in mismatches:
            print('MISMATCH', m)


if __name__ == '__main__':
    main()
