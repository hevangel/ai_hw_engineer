#!/usr/bin/env python3
"""Fetch immutable physical-chip fixtures; copy expected results, never interpret.

The fixtures are the SingleStepTests/8088 corpus, captured on a physical
NMOS AMD D8088 (a licensed second-source Intel 8088) through an Arduino8088
harness. The capture runs in maximum mode with an emulated 8288 and no wait
states. Because one run executes exactly one instruction, port reads always
return the harness value 255h, which the native runner reproduces with its
own default port fill.

The corpus provides 10,000 tests per opcode, which is far more than the
native byte-bus runner can execute in a regression. Selection is bounded and
deterministic: the first PER_FILE tests accepted per pinned corpus file, with
every exclusion counted. Each accepted test carries the physical initial
prefetch queue (at most four bytes, matching the 8088) and the ordered byte
effects decoded from the captured bus cycles.
"""
import concurrent.futures
import gzip
import hashlib
import ipaddress
import json
import re
import socket
from pathlib import Path
import struct
import urllib.parse
import urllib.request

TREE = 'aea84484abc79d09639d855b7b0ab32bc9e4dbeb'
PER_FILE = 20
REGS = 'ax cx dx bx sp bp si di es cs ss ds ip flags'.split()
PREFIXES = {0x26, 0x2e, 0x36, 0x3e, 0xf0, 0xf2, 0xf3}
SUPPORTED = set(range(256))
ALLOWED_HOSTS = {'raw.githubusercontent.com', 'api.github.com'}


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError('redirect refused: ' + newurl)


_OPENER = urllib.request.build_opener(_NoRedirect)


def memory_writes(cycles):
    """Decode the captured byte bus into ordered byte effects.

    The address/data bus column only carries the real address on the T1
    cycle of each bus cycle, and the transfer data appears on its T3 cycle;
    the status column goes passive (PASV) during T3, so the transfer kind is
    latched from T1 together with the address.
    """
    writes = []
    address = None
    kind = None
    for cycle in cycles:
        if cycle[8] == 'T1':
            address = cycle[1]
            kind = cycle[7]
        if cycle[8] == 'Tw':
            raise ValueError('Unexpected wait states in the pinned no-wait corpus')
        if cycle[8] == 'T3' and kind in ('MEMW', 'IOW'):
            if address is None:
                raise ValueError('Hardware write without a latched address')
            target = (address & 0xfffff) if kind == 'MEMW' else ((1 << 20) | (address & 65535))
            writes.append((target, cycle[6] & 255))
    return writes


def retrieve(url):
    # Downloads only from the pinned GitHub fixture hosts, with the host
    # resolved up front and non-global addresses refused (DNS-rebinding
    # guard; TLS pins the connection), redirects refused.
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != 'https' or parsed.hostname not in ALLOWED_HOSTS:
        raise ValueError('download host not allowed: ' + url)
    for info in socket.getaddrinfo(parsed.hostname, 443):
        address = ipaddress.ip_address(info[4][0])
        if not address.is_global:
            raise ValueError('resolved address is not global: ' + str(address))
    with _OPENER.open(url, timeout=90) as response:
        return response.read()


def main():
    CACHE = Path(__file__).resolve().parents[1] / 'work/reference'
    CACHE.mkdir(parents=True, exist_ok=True)
    tree_file = CACHE / 'tree.json'
    if not tree_file.exists():
        tree_file.write_bytes(retrieve(
            f'https://api.github.com/repos/SingleStepTests/8088/git/trees/{TREE}?recursive=1'))
    tree = json.loads(tree_file.read_bytes())
    if tree['sha'] != TREE or tree.get('truncated'):
        raise ValueError('Wrong or incomplete pinned source tree')
    entries = {x['path']: x for x in tree['tree'] if x['type'] == 'blob'}
    selected = [p for p in sorted(entries)
                if re.fullmatch(r'v2/[0-9A-F]{2}(\.[0-9])?\.json\.gz', p)]
    selected += ['v2/metadata.json', 'LICENSE', 'README.md']

    def fetch(path):
        dest = CACHE / path
        data = dest.read_bytes() if dest.exists() else retrieve(
            f'https://raw.githubusercontent.com/SingleStepTests/8088/{TREE}/{path}')
        blob = hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest()
        if blob != entries[path]['sha']:
            raise ValueError(f'Pinned Git blob mismatch: {path}')
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        return path, {'git_blob': blob, 'sha256': hashlib.sha256(data).hexdigest()}

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        manifest = dict(pool.map(fetch, selected))
    (CACHE / 'manifest.json').write_text(json.dumps({'tree': TREE, 'files': manifest}, indent=2)+'\n')
    metadata = json.loads((CACHE / 'v2/metadata.json').read_bytes())['opcodes']
    exclusions = {}; accepted = {}; total = 0
    output = Path(__file__).resolve().parents[1] / 'work/vectors.bin'
    with output.open('wb') as stream:
        stream.write(b'8088V1\0\0')
        for path in selected:
            if not path.endswith('.json.gz'):
                continue
            count = 0
            for test in json.loads(gzip.decompress((CACHE / path).read_bytes())):
                if count >= PER_FILE:
                    break
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
                    if reason is None and len(test['initial']['queue']) > 4:
                        reason = 'initial queue longer than the four-byte 8088 queue'
                if reason:
                    exclusions[reason] = exclusions.get(reason, 0) + 1
                    continue
                final = {**initial, **test['final']['regs']}
                flags_mask = info.get('flags-mask', 65535)
                byte_masks = {}
                if (op == 0xd4 or op in {0xf6, 0xf7} and (code[pos+1] >> 3) & 7 >= 6) and \
                        final['sp'] == (initial['sp']-6) & 65535:
                    # Divide-error and AAM stacks carry two FLAGS bytes whose
                    # undefined bits the architecture does not define; mask
                    # only those bytes, never the return address.
                    for i in range(2):
                        address=((initial['ss']<<4)+((initial['sp']-2+i)&65535))&0xfffff
                        byte_masks[address]=(flags_mask>>(8*i))&255
                label = f'{Path(path).name}:{test["idx"]} {test["name"]}'.encode()
                stream.write(struct.pack('<H', len(label))); stream.write(label)
                stream.write(struct.pack('<14H', *(initial[r] for r in REGS)))
                stream.write(struct.pack('<14H', *(final[r] for r in REGS)))
                stream.write(struct.pack('<H', flags_mask))
                queue_and_code=list(enumerate(test['initial']['queue']))
                queue_and_code += [((1<<20)|(((initial['cs']<<4)+((initial['ip']+i)&65535))&0xfffff),value)
                                   for i,value in enumerate(code)]
                initial_ram = list(dict(test['initial']['ram']).items())
                expected_ram = dict(dict(test['initial']['ram']).items())
                for address, value in dict(test['final']['ram']).items():
                    expected_ram[address] = value
                for pairs in (initial_ram, expected_ram.items(),
                              memory_writes(test['cycles']), list(byte_masks.items()),
                              queue_and_code):
                    stream.write(struct.pack('<I', len(pairs)))
                    for address, value in pairs:
                        stream.write(struct.pack('<IB', address, value))
                count += 1; total += 1
            accepted[path] = count
    if not total:
        raise ValueError('Empty fixture set')
    report = {'tree': TREE, 'per_file': PER_FILE, 'accepted': total,
              'exclusions': exclusions, 'files': accepted}
    (Path(__file__).resolve().parents[1] / 'work/vector_selection.json').write_text(
        json.dumps(report, indent=2)+'\n')
    print(f'Prepared {total} physical-chip vectors from {len(accepted)} files; exclusions: {exclusions}', flush=True)


if __name__ == '__main__':
    main()
