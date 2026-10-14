#!/usr/bin/env python3
"""Fetch pinned original IBM artifacts; convert their containers without patching."""
import hashlib
import json
from pathlib import Path
import re
import struct
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'work/reference'
PCJS = '1a91d38eb12e5fdf91116b21ad9ef1935710a496'
DISKS = 'cd3433748b09837a4c60ca7066f3642772b2d711'
ARTIFACTS = [
    ('jeffpar/pcjs', PCJS, 'machines/pcx86/ibm/5150/rom/bios/1981-04-24/PCBIOS-REV1.json5', '6782f38190a229509efc194c85579299de100166', 'bios.bin'),
    ('jeffpar/pcjs', PCJS, 'machines/pcx86/ibm/5150/rom/basic/BASIC100.json5', '09f3bce3a652e3a9ec6b19516b8f5a2d7011ba03', 'basic.bin'),
    ('jeffpar/pcjs', PCJS, 'machines/pcx86/ibm/video/cga/IBM-CGA.json5', '43944e8cb6c539e5faea06bdf1e5ba92eaab36c6', 'cga.bin'),
    ('jeffpar/pcjs-diskettes', DISKS, 'pcx86/sys/dos/ibm/1.00/PCDOS100.json', '0328d7419a74f74ce45fc0a6cdd006f9350e2711', 'pcdos100.img'),
]

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    manifest = []
    for repo, revision, source, blob, output in ARTIFACTS:
        url = f'https://raw.githubusercontent.com/{repo}/{revision}/{source}'
        cached = DEST / Path(source).name
        if not cached.exists():
            with urllib.request.urlopen(url, timeout=90) as response:
                cached.write_bytes(response.read())
        raw = cached.read_bytes()
        actual = hashlib.sha1(f'blob {len(raw)}\0'.encode() + raw).hexdigest()
        if actual != blob:
            raise ValueError(f'Pinned archive blob mismatch: {source}')
        if source.endswith('.json5'):
            text = re.sub(r'//[^\n]*', '', raw.decode())
            text = re.sub(r'0x[0-9a-fA-F]+', lambda m: str(int(m[0], 16)), text)
            text = re.sub(r',\s*([\]}])', r'\1', text)
            image = json.loads(text)
            if image['width'] != 8:
                raise ValueError('Expected original byte ROM')
            data = bytes(image['values'])
        else:
            image = json.loads(raw)
            sectors = []
            for cylinder in image['diskData']:
                for head in cylinder:
                    for sector in sorted(head, key=lambda s: s['s']):
                        words = sector.get('d', [0])
                        # PCjs short arrays repeat their last dword to sector end.
                        words = words + [words[-1]] * (sector['l']//4 - len(words))
                        sectors.append(b''.join(struct.pack('<I', w & 0xffffffff) for w in words))
            data = b''.join(sectors)
            if len(data) != 163840 or hashlib.md5(data).hexdigest() != image['imageInfo']['hash']:
                raise ValueError('Original PC160K image size/hash mismatch')
        (DEST / output).write_bytes(data)
        manifest.append({'url': url, 'git_blob': blob, 'output': output, 'bytes': len(data),
                         'sha256': hashlib.sha256(data).hexdigest()})
    if len((DEST/'bios.bin').read_bytes()) != 8192 or sum((DEST/'bios.bin').read_bytes()) & 255:
        raise ValueError('Original BIOS length/checksum')
    (DEST/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    # New writable data disk, using the independently archived PC160K FAT12
    # geometry: sector 0 reserved, two one-sector FATs, 64 root entries.
    blank=bytearray([0xf6])*163840
    blank[:7*512]=bytes(7*512)
    blank[512:515]=blank[1024:1027]=bytes([0xfe,0xff,0xff])
    (DEST/'workdisk.img').write_bytes(blank)
    print('PASS: original IBM BIOS/BASIC/CGA and PC DOS 1.00 archive integrity and conversion')

if __name__ == '__main__':
    main()
