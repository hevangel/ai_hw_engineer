#!/usr/bin/env python3
"""Import pinned physical-Harris-286 captures for most real-mode opcodes.

Evidence importer only: expected registers, RAM and exception vectors are
copied from the immutable captures, never computed. The upstream metadata
only narrows the FLAGS comparison to bits it marks defined.

Excluded files: the string files replayed by prepare_string_hardware.py.
HLT (F4) records end at the HLT under test, which the replay checks halts. Port I/O files replay with every unwritten port
reading FFh, as the capture README states. Excluded
records: initial IF/TF/IOPL/NT, a non-empty prefetch queue, TF set in the
final FLAGS, RAM inside the replay bootstrap, and revoked hashes.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import urllib.request

from hardware_moo import parse_moo
from work_paths import get_work_root

ROOT = Path(__file__).resolve().parents[1]
DEST = get_work_root(ROOT) / 'hardware'
TREE = json.loads((Path(__file__).with_name('hardware_tree_v1_real_mode.json')).read_text())
REVISION = TREE['revision']
BASE = f'https://raw.githubusercontent.com/SingleStepTests/80286/{REVISION}/'
BLOBS = {entry['path']: (entry['sha'], entry['size']) for entry in TREE['files']}
REVOCATION = ('revocation_list.txt', 'b589c24fa5316cad0899e8ceff310ab6f7f38991', 249)
REGISTERS = ('ax', 'cx', 'dx', 'bx', 'sp', 'bp', 'si', 'di', 'es', 'cs', 'ss', 'ds', 'ip', 'flags')
PREFIXES = (0x26, 0x2e, 0x36, 0x3e, 0xf0, 0xf2, 0xf3)
EXCLUDED_OPCODES = set(range(0xa4, 0xa8)) | set(range(0xaa, 0xb0))
RESERVED_MASK = 0x7fd7


def fetch(name, blob, size, url):
    cached = DEST / Path(name).name
    data = cached.read_bytes() if cached.exists() else None
    if data is None:
        with urllib.request.urlopen(url, timeout=120) as response:
            data = response.read(size + 1)
    identity = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    if len(data) != size or identity != blob:
        raise ValueError(f'Pinned hardware artifact size/Git-blob mismatch: {name}')
    if not cached.exists():
        cached.write_bytes(data)
    return data


def flag_mask(metadata, name):
    parts = Path(name).name.split('.')
    entry = metadata['opcodes'][parts[0]]
    if len(parts) == 4:  # e.g. F7.4.MOO.gz
        entry = entry['reg'][parts[1]]
    return entry.get('flags-mask', 0xffff) & RESERVED_MASK


def select(test, opcode, mask):
    initial = test['initial']['regs']
    final = {**initial, **test['final']['regs']}
    if set(initial) != set(REGISTERS):
        raise ValueError('incomplete physical register state')
    if initial['flags'] & 0x7300:
        return 'IF/TF/IOPL/NT setup'
    if final['flags'] & 0x100:
        return 'final TF'
    if test['initial']['queue'] or test['final']['queue']:
        return 'prefetch queue'
    code = test['bytes']
    i = 0
    while i < len(code) and code[i] in PREFIXES:
        i += 1
    if i >= len(code) or code[i] != opcode:
        raise ValueError(f'unexpected encoding {bytes(code).hex()}')
    if len(code) > 12:
        return 'encoding longer than replay field'
    initial_ram = dict(test['initial']['ram'])
    final_ram = {**initial_ram, **dict(test['final']['ram'])}
    if any(address >= 0xff0000 for address in set(initial_ram) | set(final_ram)):
        return 'RAM aliases bootstrap'
    exception = test.get('exception')
    if exception and mask != RESERVED_MASK:
        # The pushed FLAGS word contains bits the metadata marks undefined.
        for address in (exception['flag_address'], exception['flag_address'] + 1):
            final_ram.pop(address, None)
    return initial, final, initial_ram, final_ram, exception


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--per-file', type=int, default=0, help='records per file (0 = all)')
    parser.add_argument('--only', nargs='*', default=None, help='file name prefixes to import')
    args = parser.parse_args()
    DEST.mkdir(parents=True, exist_ok=True)
    metadata = json.loads(fetch('metadata.json', *BLOBS['metadata.json'],
                                BASE + 'v1_real_mode/metadata.json'))
    revoked = {line.strip() for line in
               fetch(REVOCATION[0], REVOCATION[1], REVOCATION[2], BASE + REVOCATION[0]).decode().splitlines()
               if line.strip() and not line.startswith('#')}
    accounting = {}
    total = 0
    with (DEST / 'general_vectors.txt').open('w') as output:
        for path, (blob, size) in sorted(BLOBS.items()):
            if not path.endswith('.MOO.gz'):
                continue
            opcode = int(path[:2], 16)
            if opcode in EXCLUDED_OPCODES:
                continue
            if args.only is not None and not any(path.startswith(p) for p in args.only):
                continue
            file_mask = flag_mask(metadata, path)
            data = fetch(path, blob, size, BASE + 'v1_real_mode/' + path)
            tally = {}
            for test in parse_moo(gzip.decompress(data))['tests']:
                if args.per_file and tally.get('selected', 0) + tally.get('selected_fault', 0) >= args.per_file:
                    break
                if test['hash'] in revoked:
                    tally['revoked'] = tally.get('revoked', 0) + 1
                    continue
                result = select(test, opcode, file_mask)
                if isinstance(result, str):
                    tally[result] = tally.get(result, 0) + 1
                    continue
                initial, final, initial_ram, final_ram, exception = result
                label = f'{path}:{test["idx"]}:{test["hash"]}'
                mask = file_mask
                if opcode == 0xc0 and test['bytes'][-2] & 0x1f != 1:
                    # The metadata lists no undefined flags for C0 /n, unlike
                    # C1 /n and D2 /n. Intel leaves OF undefined for a
                    # multi-bit count, so use the matching C1 /n mask; a count
                    # of 1 keeps the full comparison.
                    mask = flag_mask(metadata, 'C1' + path[2:])
                code = bytes(test['bytes']).hex()
                if exception and opcode not in (0xcc, 0xcd, 0xce):
                    # INT3/INT n/INTO retire into their handler; other
                    # captured exceptions enter the handler without retiring.
                    tally['selected_fault'] = tally.get('selected_fault', 0) + 1
                    output.write(f'HWGENFAULT {label} {code} {opcode:x} {mask:x} {exception["number"]:x}\n')
                else:
                    tally['selected'] = tally.get('selected', 0) + 1
                    output.write(f'HWGEN {label} {code} {opcode:x} {mask:x}\n')
                for tag, regs in (('INITIAL', initial), ('FINAL', final)):
                    output.write(tag + ' ' + ' '.join(f'{regs[k]:x}' for k in REGISTERS) + '\n')
                for tag, memory in (('RAM_INITIAL', initial_ram), ('RAM_FINAL', final_ram)):
                    output.write(f'{tag} {len(memory):x}')
                    for address, byte in sorted(memory.items()):
                        output.write(f' {address:x} {byte:x}')
                    output.write('\n')
                output.write('END\n')
            accounting[path] = tally
            total += tally.get('selected', 0) + tally.get('selected_fault', 0)
    (DEST / 'general_manifest.json').write_text(json.dumps(
        {'revision': REVISION, 'record_accounting': accounting, 'cases': total}, indent=2) + '\n')
    print(f'PASS: imported {total} physical-286 records from {len(accounting)} opcode files')


if __name__ == '__main__':
    main()
