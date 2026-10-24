#!/usr/bin/env python3
"""Fetch immutable independent test artifacts; every cached byte is checked."""
import concurrent.futures
import hashlib
import ipaddress
import json
import socket
from pathlib import Path
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = json.loads((ROOT / 'tb/external_manifest.json').read_text())
DEST = ROOT / 'work/external'
HOST = 'raw.githubusercontent.com'


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError('redirect refused: ' + newurl)


_OPENER = urllib.request.build_opener(_NoRedirect)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def open_pinned(url, timeout=90):
    # Downloads only from the pinned GitHub raw host; the host is resolved
    # up front with non-global addresses refused (DNS-rebinding guard; TLS
    # pins the connection), redirects refused, and every artifact is
    # checksummed before use.
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != 'https' or parsed.hostname != HOST:
        raise ValueError('download host not allowed: ' + url)
    for info in socket.getaddrinfo(parsed.hostname, 443):
        address = ipaddress.ip_address(info[4][0])
        if not address.is_global:
            raise ValueError('resolved address is not global: ' + str(address))
    return _OPENER.open(url, timeout=timeout)


def download(repository, commit, name, path, expected):
    if not path.exists():
        url = f'https://raw.githubusercontent.com/{repository}/{commit}/{name}'
        data = open_pinned(url).read()
        if digest(data) != expected:
            raise RuntimeError(f'Checksum mismatch: {name}')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    if digest(path.read_bytes()) != expected:
        raise RuntimeError(f'Corrupt cache: {path}')


def vector(item):
    op, entry = item
    path = DEST / (op + '.json')
    if not path.exists():
        commit = MANIFEST['vectors']['commit']
        url = f'https://raw.githubusercontent.com/SingleStepTests/65x02/{commit}/6502/v1/{op}.json'
        cases = []
        with open_pinned(url) as response:
            for line in response:
                line = line.decode().strip().rstrip(',')
                if line.startswith('{'):
                    cases.append(json.loads(line))
                    if len(cases) == entry['cases']:
                        break
        if len(cases) != entry['cases']:
            raise RuntimeError(f'Incomplete vectors: {op}')
        data = json.dumps(cases, separators=(',', ':')).encode('ascii')
        if digest(data) != entry['sha256']:
            raise RuntimeError(f'Vector checksum mismatch: {op}')
        path.write_bytes(data)
    if digest(path.read_bytes()) != entry['sha256']:
        raise RuntimeError(f'Corrupt vector cache: {op}')


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(vector, MANIFEST['vectors']['files'].items()))
    (DEST / 'vectors_manifest.json').write_text(json.dumps(MANIFEST['vectors']))
    for name, expected in MANIFEST['klaus']['files'].items():
        download('Klaus2m5/6502_65C02_functional_tests', MANIFEST['klaus']['commit'],
                 name, DEST / Path(name).name, expected)
    for name, expected in MANIFEST['py65']['files'].items():
        download('mnaberez/py65', MANIFEST['py65']['commit'], name,
                 DEST / 'python' / name, expected)
    print('PASS pinned independent CPU artifact checksums')


if __name__ == '__main__':
    main()
