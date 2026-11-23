#!/usr/bin/env python3
"""Fetch and verify pinned original IBM PC DOS 3.00 Disk 1 image (360 KiB).

Writes $IBM_PC_AT_WORK_DIR/software/pcdos300.img (or system/ibm_pc_at_5170/work/software/pcdos300.img)
and prints its path. Downloaded and converted bytes stay in ignored work/.
"""
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import socket
import struct
import sys
import urllib.parse
import urllib.request

SYS_DIR = Path(__file__).resolve().parents[1]
WORK_DIR = Path(os.environ.get('IBM_PC_AT_WORK_DIR', SYS_DIR / 'work'))
DEST = WORK_DIR / 'software'
HOST = 'raw.githubusercontent.com'
REV = 'cd3433748b09837a4c60ca7066f3642772b2d711'
SOURCE = 'pcx86/sys/dos/ibm/3.00/PCDOS300-DISK1.json'
BLOB_SHA1 = 'db4c0627c37d8e7ecd33b56dcdb1960a0c4da4c1'
URL = f'https://{HOST}/jeffpar/pcjs-diskettes/{REV}/{SOURCE}'


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError('redirect refused: ' + newurl)


_OPENER = urllib.request.build_opener(_NoRedirect)


def open_pinned(url, timeout=60):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != 'https' or parsed.hostname != HOST:
        raise ValueError('download host not allowed: ' + url)
    for info in socket.getaddrinfo(parsed.hostname, 443):
        address = ipaddress.ip_address(info[4][0])
        if not address.is_global:
            raise ValueError('resolved address is not global: ' + str(address))
    return _OPENER.open(url, timeout=timeout)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    cached = DEST / 'PCDOS300-DISK1.json'
    if not cached.exists():
        with open_pinned(URL) as r:
            cached.write_bytes(r.read())
    raw = cached.read_bytes()
    actual_blob = hashlib.sha1(f'blob {len(raw)}\0'.encode() + raw).hexdigest()
    if actual_blob != BLOB_SHA1:
        raise ValueError(f'PC DOS archive blob mismatch: {actual_blob} != {BLOB_SHA1}')
    image = json.loads(raw)
    sectors = []
    for cylinder in image['diskData']:
        for head in cylinder:
            for sector in sorted(head, key=lambda s: s['s']):
                words = sector.get('d', [0])
                words = words + [words[-1]] * (sector['l'] // 4 - len(words))
                sectors.append(b''.join(struct.pack('<I', w & 0xffffffff) for w in words))
    data = b''.join(sectors)
    expected_md5 = image['imageInfo']['hash']
    if len(data) != 368640 or hashlib.md5(data).hexdigest() != expected_md5:
        raise ValueError('PC DOS 3.00 image size or MD5 mismatch')
    out = DEST / 'pcdos300.img'
    out.write_bytes(data)
    sys.stderr.write(f'PCDOS300 {out} ({len(data)} bytes, sha256={hashlib.sha256(data).hexdigest()})\n')
    print(out)


if __name__ == '__main__':
    main()
