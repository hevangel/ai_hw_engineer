#!/usr/bin/env python3
"""Fetch immutable physical-chip fixtures; copy expected results, never interpret."""
import concurrent.futures
import gzip
import hashlib
import json
from pathlib import Path
import struct
import urllib.request

COMMIT = 'e71c68d215a6bb8c356bd4cb3842de3bef345ca9'
ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'work/reference'
REGS = 'ax cx dx bx sp bp si di es cs ss ds ip flags'.split()
PREFIXES = {0x26, 0x2e, 0x36, 0x3e, 0xf0, 0xf2, 0xf3}
SUPPORTED = set(range(256))


def memory_writes(cycles):
    """Expand native byte lanes into ordered byte effects, ignoring cycle timing."""
    writes = []
    address = bhe = None
    for cycle in cycles:
        if cycle[0] & 1:  # ALE: only T1 contains a valid physical address.
            address, bhe = cycle[1], cycle[5]
        if cycle[8] == 'Tw':
            raise ValueError('Unexpected wait states in the pinned no-wait corpus')
        if cycle[8] == 'T3' and (cycle[3][1] == 'A' or cycle[4][1] == 'A'):
            if address is None:
                raise ValueError('Hardware write without a latched address')
            space = (1 << 20) if cycle[4][1] == 'A' else 0
            if not address & 1:
                writes.append((address | space, cycle[6] & 255))
            if not bhe:
                writes.append((address | 1 | space, cycle[6] >> 8))
    return writes


def retrieve(url):
    with urllib.request.urlopen(url, timeout=90) as response:
        return response.read()


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    tree_file = CACHE / 'tree.json'
    if not tree_file.exists():
        tree_file.write_bytes(retrieve(f'https://api.github.com/repos/SingleStepTests/8086/git/trees/{COMMIT}?recursive=1'))
    tree = json.loads(tree_file.read_bytes())
    if tree['sha'] != COMMIT or tree.get('truncated'):
        raise ValueError('Wrong or incomplete pinned source tree')
    entries = {x['path']: x for x in tree['tree'] if x['type'] == 'blob'}
    selected = [p for p in entries if p.startswith('v1/') and p.endswith('.json.gz')
                and int(Path(p).name[:2], 16) in SUPPORTED]
    selected += ['v1/metadata.json', 'LICENSE', 'README.md']

    def fetch(path):
        dest = CACHE / path
        data = dest.read_bytes() if dest.exists() else retrieve(
            f'https://raw.githubusercontent.com/SingleStepTests/8086/{COMMIT}/{path}')
        blob = hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest()
        if blob != entries[path]['sha']:
            raise ValueError(f'Pinned Git blob mismatch: {path}')
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        return path, {'git_blob': blob, 'sha256': hashlib.sha256(data).hexdigest()}

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        manifest = dict(pool.map(fetch, selected))
    (CACHE / 'manifest.json').write_text(json.dumps({'commit': COMMIT, 'files': manifest}, indent=2)+'\n')
    metadata = json.loads((CACHE / 'v1/metadata.json').read_bytes())['opcodes']
    exclusions = {}; accepted = {}; total = 0
    output = ROOT / 'work/vectors.bin'
    with output.open('wb') as stream:
        stream.write(b'8086V4\0\0')
        for path in sorted(p for p in selected if p.endswith('.gz')):
            count = 0
            for test in json.loads(gzip.decompress((CACHE / path).read_bytes())):
                code = test['bytes']; pos = 0
                while pos < len(code) and code[pos] in PREFIXES:
                    pos += 1
                if pos == len(code) or code[pos] not in SUPPORTED:
                    reason = 'unsupported prefix or opcode'
                else:
                    op = code[pos]; info = metadata[f'{op:02X}']; reason = None
                    if 'reg' in info:
                        info = {**info, **info['reg'].get(str((code[pos+1] >> 3) & 7), {})}
                    if info.get('status') not in {'normal', 'fpu'}:
                        reason = 'upstream non-normal encoding'
                    elif op in {0x8c, 0x8e} and (((code[pos+1] >> 3) & 7) > 3 or
                                                op == 0x8e and (code[pos+1] >> 3) & 7 == 1):
                        reason = 'undocumented segment-register field'
                    elif op in {0x8d, 0xc4, 0xc5} and code[pos+1] >> 6 == 3:
                        reason = 'invalid far-pointer/LEA register form'
                    elif op in {0xc6, 0xc7} and (code[pos+1] >> 3) & 7:
                        reason = 'undocumented immediate MOV extension'
                    initial = test['initial']['regs']
                    ram = dict(test['initial']['ram'])
                    if reason is None and any(ram.get(((initial['cs'] << 4) +
                         ((initial['ip'] + i) & 65535)) & 0xfffff) != value for i,value in enumerate(code)):
                        reason = 'instruction queue differs from fetchable RAM'
                if reason:
                    exclusions[reason] = exclusions.get(reason, 0) + 1
                    continue
                final = {**initial, **test['final']['regs']}
                flags_mask = info.get('flags-mask', 65535)
                if op in {0xd2,0xd3} and initial['cx'] & 255 <= 1:
                    flags_mask = 65535 if initial['cx'] & 255 == 0 else flags_mask | 0x800
                byte_masks = {}
                if (op==0xd4 or op in {0xf6,0xf7} and (code[pos+1]>>3)&7 >= 6) and \
                        final['sp'] == (initial['sp']-6)&65535:
                    for i in range(2):
                        address=((initial['ss']<<4)+((initial['sp']-2+i)&65535))&0xfffff
                        byte_masks[address]=(flags_mask>>(8*i))&255
                label = f'{Path(path).name}:{test["test_num"]} {test["name"]}'.encode()
                stream.write(struct.pack('<H', len(label))); stream.write(label)
                stream.write(struct.pack('<14H', *(initial[r] for r in REGS)))
                stream.write(struct.pack('<14H', *(final[r] for r in REGS)))
                stream.write(struct.pack('<H', flags_mask))
                queue_and_code=list(enumerate(test['initial']['queue']))
                queue_and_code += [((1<<20)|(((initial['cs']<<4)+((initial['ip']+i)&65535))&0xfffff),value)
                                   for i,value in enumerate(code)]
                for pairs in (test['initial']['ram'], test['final']['ram'], memory_writes(test['cycles']),
                              list(byte_masks.items()), queue_and_code):
                    stream.write(struct.pack('<I', len(pairs)))
                    for address, value in pairs:
                        stream.write(struct.pack('<IB', address, value))
                count += 1; total += 1
            accepted[path] = count
    if not total:
        raise ValueError('Empty fixture set')
    report = {'commit': COMMIT, 'accepted': total, 'exclusions': exclusions, 'files': accepted}
    (ROOT / 'work/vector_selection.json').write_text(json.dumps(report, indent=2)+'\n')
    print(f'Prepared {total} physical-chip vectors in {len(accepted)} files; exclusions: {exclusions}', flush=True)


if __name__ == '__main__':
    main()
