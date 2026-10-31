#!/usr/bin/env python3
"""Integrity-check and decode an unchanged, revision-pinned original IBM AT ROM."""
import hashlib
import json
from pathlib import Path
import re
import urllib.request

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
DEST = WORK_ROOT / 'software'
REVISION = '1a91d38eb12e5fdf91116b21ad9ef1935710a496'
SOURCE = 'machines/pcx86/ibm/5170/rom/bios/1984-01-10/ATBIOS-REV1.json5'
URL = f'https://raw.githubusercontent.com/jeffpar/pcjs/{REVISION}/{SOURCE}'
SHA256 = '3b1a6c8cd59a5ac725809a90de0808f7965c34be229099339203fccba0b2bde6'


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    cached = DEST / 'ATBIOS-REV1.json5'
    if not cached.exists():
        with urllib.request.urlopen(URL, timeout=90) as response:
            raw = response.read()
        if hashlib.sha256(raw).hexdigest() != SHA256:
            raise ValueError('Downloaded IBM AT archive SHA256 mismatch')
        cached.write_bytes(raw)
    raw = cached.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SHA256:
        raise ValueError('Cached IBM AT archive SHA256 mismatch')
    text = re.sub(r'//[^\n]*', '', raw.decode())
    text = re.sub(r'0x[0-9a-fA-F]+', lambda m: str(int(m[0], 16)), text)
    text = re.sub(r',\s*([\]}])', r'\1', text)
    image = json.loads(text)
    if image['width'] != 8:
        raise ValueError('Expected byte ROM archive')
    data = bytes(image['values'])
    if len(data) != 65536 or sum(data) & 255:
        raise ValueError('Original AT ROM length/checksum mismatch')
    if data[0xfff0:0xfff5] != bytes.fromhex('ea 5b e0 00 f0'):
        raise ValueError('Original AT reset vector mismatch')
    (DEST / 'atbios.bin').write_bytes(data)
    (DEST / 'manifest.json').write_text(json.dumps({
        'url': URL, 'archive_sha256': SHA256,
        'rom_sha256': hashlib.sha256(data).hexdigest(), 'rom_bytes': len(data),
        'scope': 'Independent CPU trace through flags/register tests and ROM-checksum success; no full POST/boot claim',
    }, indent=2) + '\n')
    print('PASS: pinned original IBM AT BIOS archive and ROM integrity')


if __name__ == '__main__':
    main()
