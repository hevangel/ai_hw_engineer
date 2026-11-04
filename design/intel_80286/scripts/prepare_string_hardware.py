#!/usr/bin/env python3
"""Import pinned physical-Harris-286 string-instruction captures (MOVS/CMPS/STOS/LODS/SCAS).

Evidence importer only: expected state is copied from the immutable captures,
never computed. Selects records that complete without an exception, start with
IF/TF/IOPL/NT clear and an empty prefetch queue, and encode prefixes + string
opcode + HLT. REP/REPNE prefixes are kept: the captures pin how the 286 treats
REPNE with non-compare strings and REP with LODS (assumption A36).
"""
import gzip
import hashlib
import json
from pathlib import Path
import urllib.request

from hardware_moo import parse_moo
from work_paths import get_work_root

ROOT = Path(__file__).resolve().parents[1]
DEST = get_work_root(ROOT) / 'hardware'
REVISION = '37c73caf53dcd22d3dd369ff09305d13d117a4fe'
BASE = f'https://raw.githubusercontent.com/SingleStepTests/80286/{REVISION}/'
# Git blob identities/sizes from the revision-pinned tree.
FILES = {
    'revocation_list.txt': ('b589c24fa5316cad0899e8ceff310ab6f7f38991', 249),
    'v1_real_mode/A4.MOO.gz': ('c63ca1ed3be44d7f90ac37d2ad7b83ac4d80b394', 2093459),
    'v1_real_mode/A5.MOO.gz': ('0a56848e060f0d0f0c9bb72da3631fe9265a69b5', 2720022),
    'v1_real_mode/A6.MOO.gz': ('aa9d30cd31fcd1cf918fb0835dd0a3d66256365f', 1648926),
    'v1_real_mode/A7.MOO.gz': ('ee6db9ba4e504c89950e8e46588f6d7af683bf1c', 2059643),
    'v1_real_mode/AA.MOO.gz': ('e2bf205052a051404c0947c06f8b0a836f68633e', 1216613),
    'v1_real_mode/AB.MOO.gz': ('23101a0aba64a2539460ba95ba386742eff7d0ba', 1469683),
    'v1_real_mode/AC.MOO.gz': ('bfee697bafee3334de3915ce35aae89e0268f83e', 1642616),
    'v1_real_mode/AD.MOO.gz': ('158ee0453f13fd69bb01473c5c01c52d6cefc11b', 2012834),
    'v1_real_mode/AE.MOO.gz': ('5d7632cdfaadb77682b7e787cae46446568ab902', 1272804),
    'v1_real_mode/AF.MOO.gz': ('c959aa25cee888402236a7bfc7d124a589fd5acb', 1538315),
}
REGISTERS = ('ax', 'cx', 'dx', 'bx', 'sp', 'bp', 'si', 'di', 'es', 'cs', 'ss', 'ds', 'ip', 'flags')
PREFIXES = (0x26, 0x2e, 0x36, 0x3e, 0xf0, 0xf2, 0xf3)
FLAGS_MASK = 0x7fd7


def fetch(path):
    blob, size = FILES[path]
    cached = DEST / Path(path).name
    if cached.exists():
        data = cached.read_bytes()
    else:
        with urllib.request.urlopen(BASE + path, timeout=90) as response:
            data = response.read(size + 1)
    identity = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    if len(data) != size or identity != blob:
        raise ValueError(f'Pinned hardware artifact size/Git-blob mismatch: {path}')
    if not cached.exists():
        cached.write_bytes(data)
    return data


def select(test, opcode):
    """Return (initial, final, initial_ram, final_ram) or a skip reason string."""
    exception = test.get('exception')
    if exception and exception['number'] != 13:
        return 'non-13 exception'
    initial = test['initial']['regs']
    final = {**initial, **test['final']['regs']}
    if set(initial) != set(REGISTERS) or set(final) != set(REGISTERS):
        raise ValueError('incomplete physical register state')
    if initial['flags'] & 0x7300:
        return 'IF/TF/IOPL/NT setup'
    if test['initial']['queue'] or test['final']['queue']:
        return 'prefetch queue'
    code = test['bytes']
    i = 0
    while i < len(code) and code[i] in PREFIXES:
        i += 1
    if i != len(code) - 2 or code[i] != opcode or code[-1] != 0xf4:
        raise ValueError(f'unexpected encoding {bytes(code).hex()}')
    if not exception and (final['cs'] != initial['cs'] or
                          final['ip'] != (initial['ip'] + len(code)) & 0xffff):
        raise ValueError('non-flow PC accounting mismatch')
    initial_ram = dict(test['initial']['ram'])
    final_ram = {**initial_ram, **dict(test['final']['ram'])}
    start = initial['cs'] * 16 + initial['ip']
    for k, byte in enumerate(code):
        if initial_ram.get(start + k) != byte:
            raise ValueError('encoded instruction differs from initial RAM')
    if any(address >= 0xff0000 for address in initial_ram):
        return 'RAM aliases bootstrap'
    return initial, final, initial_ram, final_ram


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    payloads = {path: fetch(path) for path in FILES}
    revoked = {line.strip() for line in payloads['revocation_list.txt'].decode().splitlines()
               if line.strip() and not line.startswith('#')}
    counts = {}
    selected = 0
    with (DEST / 'string_vectors.txt').open('w') as output:
        for path, data in payloads.items():
            if not path.endswith('.MOO.gz'):
                continue
            opcode = int(Path(path).name[:2], 16)
            tally = {}
            for test in parse_moo(gzip.decompress(data))['tests']:
                if test['hash'] in revoked:
                    tally['revoked'] = tally.get('revoked', 0) + 1
                    continue
                result = select(test, opcode)
                if isinstance(result, str):
                    tally[result] = tally.get(result, 0) + 1
                    continue
                initial, final, initial_ram, final_ram = result
                label = f'{Path(path).name}:{test["idx"]}:{test["hash"]}'
                code = bytes(test["bytes"]).hex()
                if test.get('exception'):
                    tally['selected_fault'] = tally.get('selected_fault', 0) + 1
                    output.write(f'HWSTRFAULT {label} {code} {opcode:x} {FLAGS_MASK:x} {13:x}\n')
                else:
                    tally['selected'] = tally.get('selected', 0) + 1
                    output.write(f'HWSTRING {label} {code} {opcode:x} {FLAGS_MASK:x}\n')
                for tag, regs in (('INITIAL', initial), ('FINAL', final)):
                    output.write(tag + ' ' + ' '.join(f'{regs[k]:x}' for k in REGISTERS) + '\n')
                for tag, memory in (('RAM_INITIAL', initial_ram), ('RAM_FINAL', final_ram)):
                    output.write(f'{tag} {len(memory):x}')
                    for address, byte in sorted(memory.items()):
                        output.write(f' {address:x} {byte:x}')
                    output.write('\n')
                output.write('END\n')
            counts[path] = tally
            selected += tally.get('selected', 0) + tally.get('selected_fault', 0)
    (DEST / 'string_manifest.json').write_text(json.dumps(
        {'revision': REVISION, 'record_accounting': counts, 'cases': selected}, indent=2) + '\n')
    print(f'PASS: imported {selected} physical-286 string records; accounting {json.dumps(counts)}')


if __name__ == '__main__':
    main()
