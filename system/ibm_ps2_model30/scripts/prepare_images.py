#!/usr/bin/env python3
"""Cache authentic Model 30 ROM/media, verify bytes, and convert containers."""
import hashlib
import io
import ipaddress
import json
import socket
from pathlib import Path
import struct
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT/'work/reference'
ALLOWED_HOSTS = {'www.ardent-tool.com', 'www.ibmfiles.com',
                 'raw.githubusercontent.com'}
ARTIFACTS = [
    ('https://www.ardent-tool.com/firmware/system/8530/8086/61X8940.zip',
     'd01a6e46ce0e293ab20710a622e23ea624a78a78b99692c380291a1d4b9a8456', '61X8940.zip'),
    ('https://www.ardent-tool.com/firmware/system/8530/8086/61X8939.zip',
     '5f677f30f3a96380fb9e9f1295df85b0a58c707d6750ecec6b6cea2f56bd5b53', '61X8939.zip'),
    ('https://www.ibmfiles.com/ibmfiles/ps2/hamilton/30start.zip',
     '05207655e2d5a8bd2f39b478cbd11c638bf19d0cc5804eb8c0073f392ce37faa', '30start.zip'),
]
DOS_URL = ('https://raw.githubusercontent.com/jeffpar/pcjs-diskettes/'
           'cd3433748b09837a4c60ca7066f3642772b2d711/pcx86/sys/dos/ibm/3.30/PCDOS330-720K-DISK1.json')

class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError('redirect refused: ' + newurl)


_OPENER = urllib.request.build_opener(_NoRedirect)


def fetch(url, name):
    # Downloads only from the pinned archival hosts, each resolved up front
    # with non-global addresses refused (DNS-rebinding guard; TLS pins the
    # connection), redirects refused; every artifact is hash-verified
    # before use.
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != 'https' or parsed.hostname not in ALLOWED_HOSTS:
        raise ValueError('download host not allowed: ' + url)
    for info in socket.getaddrinfo(parsed.hostname, 443):
        address = ipaddress.ip_address(info[4][0])
        if not address.is_global:
            raise ValueError('resolved address is not global: ' + str(address))
    file = DEST/name
    if not file.exists():
        with _OPENER.open(url, timeout=90) as response:
            file.write_bytes(response.read())
    return file.read_bytes()

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = []
    for url, digest, name in ARTIFACTS:
        raw = fetch(url, name)
        if hashlib.sha256(raw).hexdigest() != digest:
            raise ValueError(f'Archive integrity: {name}')
        manifest.append({'url': url, 'sha256': digest})
    even = zipfile.ZipFile(io.BytesIO((DEST/'61X8940.zip').read_bytes())).read('61X8940.BIN')
    odd = zipfile.ZipFile(io.BytesIO((DEST/'61X8939.zip').read_bytes())).read('61X8939.BIN')
    if len(even) != 32768 or len(odd) != 32768:
        raise ValueError('Original socket size')
    bios = bytearray(65536)
    bios[::2], bios[1::2] = even, odd
    if sum(bios)&255 or bios[-11:-3] != b'02/05/87':
        raise ValueError('Original BIOS checksum/date')
    if hashlib.sha256(bios).hexdigest() != 'a14c037422422e146a84c2c21a599001100e4e0955ecaf7a0e52031347445bea':
        raise ValueError('Interleaved BIOS integrity')
    (DEST/'bios.bin').write_bytes(bios)
    starter = zipfile.ZipFile(io.BytesIO((DEST/'30start.zip').read_bytes())).read('30start.img')
    if len(starter) != 737280:
        raise ValueError('Starter Disk geometry')
    (DEST/'starter.img').write_bytes(starter)
    raw = fetch(DOS_URL, 'PCDOS330-720K-DISK1.json')
    if hashlib.sha1(f'blob {len(raw)}\0'.encode()+raw).hexdigest() != 'c27ecab517ddf12f8937be555a6ebfd7a9c29017':
        raise ValueError('Pinned PC DOS archive blob')
    disk = json.loads(raw)
    sectors = []
    for cylinder in disk['diskData']:
        for head in cylinder:
            for sector in sorted(head, key=lambda s: s['s']):
                words = sector.get('d', [0])
                words += [words[-1]]*(sector['l']//4-len(words))
                sectors.append(b''.join(struct.pack('<I', w&0xffffffff) for w in words))
    dos = b''.join(sectors)
    if len(dos) != 737280 or hashlib.md5(dos).hexdigest() != disk['imageInfo']['hash']:
        raise ValueError('PC DOS original image integrity')
    (DEST/'pcdos330.img').write_bytes(dos)
    (DEST/'boot.img').write_bytes(dos)
    # Blank unformatted 720 KiB decoded media. Original DOS FORMAT initializes it.
    if not (DEST/'workdisk.img').exists():
        (DEST/'workdisk.img').write_bytes(bytes([0xf6])*737280)
    manifest.append({'url': DOS_URL, 'git_blob': 'c27ecab517ddf12f8937be555a6ebfd7a9c29017'})
    for name in ('bios.bin','starter.img','pcdos330.img'):
        data = (DEST/name).read_bytes()
        manifest.append({'output': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
    (DEST/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print('PASS: Model 30 original socket ROMs, Starter Disk and PC DOS 3.30 integrity/conversion')

if __name__ == '__main__':
    main()
