#!/usr/bin/env python3
"""Rebuild the IBM PC AT 8042 firmware (part 1503033) and prove it by hash.

A. Tarpai (Halicery) published a 2010 commented disassembly of the IBM
1503033 ROM under the MIT licence. It prints every disassembled address with
its bytes: 1,388 of the ROM's 2,048 bytes. The repository carries it as the
opt-in submodule external/halicery/8042.

The other 660 bytes are never executed. In the real chip they are:
  - 009h-020h: the 24-character identification string in ID_STRING;
  - everything else: 00h.
This was established from the dump published by minuszerodegrees.net
(DUMP_URL). The script does not need that dump: it rebuilds the image from
the listing, the string and 00h fill, then requires the result to match the
hashes MAME records for 1503033.bin (CRC32 5a81c0d2, SHA-1 DUMP_SHA1). A
wrong byte anywhere fails the run.

Steps: read the listing from the submodule (or, if it is not checked out,
download the same file at the pinned commit), convert CRLF to LF, check its
SHA-256, rebuild, check SHA-1 and CRC32, and write:

  work/firmware/1503033.bin          the verified 2,048-byte ROM image
  work/firmware/1503033_known.json   listed-byte map, gap ranges, hashes

The image is IBM's copyrighted firmware and stays in the ignored work
folder. --dump PATH also cross-checks a separately obtained dump against the
same hashes and the rebuilt image.

Usage: rebuild_1503033.py [--work DIR] [--dump PATH]
Prints the path of the image to use.
"""
import argparse
import hashlib
import json
import re
import sys
import urllib.request
import zlib
from pathlib import Path

REVISION = '6ddf1669224342663ed1fc6e9a33f3577ad9ba02'
SOURCE = '8042_1503033.TXT'
URL = f'https://raw.githubusercontent.com/Halicery/8042/{REVISION}/{SOURCE}'
SUBMODULE = Path(__file__).resolve().parents[4] / 'external' / 'halicery' / '8042'
# SHA-256 of the listing with LF line endings. The PCjs archive copy
# (jeffpar/pcjs 1a91d38e, machines/pcx86/ibm/keyboard/) has the same content.
LISTING_SHA256 = '3e10124dfba23726c2e11c2f50812fd1190828f6dd7bc54a4b4d186d1fa5ca98'
# MAME src/devices/machine/at_keybc.cpp, ROM "1503033.bin".
DUMP_SHA1 = '0100f8789fb4de74706ae7f9473a12ec2b9bd729'
DUMP_CRC32 = 0x5a81c0d2
DUMP_SHA256 = '7c97449f3546f7528165d6f0670ec36934bfbdb42fd7ce7b9d18bf9736c3a515'
DUMP_URL = ('https://www.minuszerodegrees.net/rom/bin/'
            'ibm_1503033_5170_kyb_controller_on_motherboard.bin')
KNOWN_BYTES = 1388
ID_ADDRESS = 0x009
ID_STRING = b' 1503033 CORP. IBM 1983 '
LINE = re.compile(r'^\s*([0-9A-Fa-f]{4}):((?: (?:\| )?[0-9A-Fa-f]{2})+)(?=\s|$)')


def parse_listing(text):
    """Return {address: byte} from 'AAAA: BB BB  MNEMONIC' lines and the
    'AAAA: bb bb ... | bb ...' table rows."""
    mem = {}
    for line in text.splitlines():
        m = LINE.match(line)
        if not m:
            continue
        base = int(m.group(1), 16)
        for i, tok in enumerate(t for t in m.group(2).split() if t != '|'):
            addr = base + i
            val = int(tok, 16)
            if addr in mem and mem[addr] != val:
                raise ValueError('listing disagrees with itself at %03X' % addr)
            mem[addr] = val
    return mem


def gaps(mem):
    out, start = [], None
    for x in range(2048):
        if x not in mem and start is None:
            start = x
        elif x in mem and start is not None:
            out.append([start, x - 1])
            start = None
    if start is not None:
        out.append([start, 2047])
    return out


def checked(raw, what):
    raw = raw.replace(b'\r\n', b'\n')
    if hashlib.sha256(raw).hexdigest() != LISTING_SHA256:
        raise ValueError('%s 1503033 listing SHA-256 mismatch' % what)
    return raw


def fetch_listing(cache):
    """Return the listing text and where it came from."""
    local = SUBMODULE / SOURCE
    if local.exists():
        raw = checked(local.read_bytes(), 'submodule')
        cache.write_bytes(raw)
        return raw.decode('utf-8'), 'external/halicery/8042@' + REVISION
    if not cache.exists():
        print('external/halicery/8042 is not checked out; downloading ' + URL,
              file=sys.stderr)
        with urllib.request.urlopen(URL, timeout=90) as response:
            cache.write_bytes(checked(response.read(), 'downloaded'))
    return checked(cache.read_bytes(), 'cached').decode('utf-8'), URL


def check_image(image, what):
    if len(image) != 2048:
        raise ValueError('%s is %d bytes, expected 2048' % (what, len(image)))
    if hashlib.sha1(image).hexdigest() != DUMP_SHA1:
        raise ValueError('%s SHA-1 does not match MAME 1503033.bin' % what)
    if zlib.crc32(image) != DUMP_CRC32:
        raise ValueError('%s CRC32 does not match MAME 1503033.bin' % what)
    if hashlib.sha256(image).hexdigest() != DUMP_SHA256:
        raise ValueError('%s SHA-256 mismatch' % what)


def main():
    here = Path(__file__).resolve().parents[1]
    ap = argparse.ArgumentParser()
    ap.add_argument('--work', default=str(here / 'work'))
    ap.add_argument('--dump')
    args = ap.parse_args()
    dest = Path(args.work) / 'firmware'
    dest.mkdir(parents=True, exist_ok=True)
    text, source = fetch_listing(dest / '8042_1503033.TXT')
    mem = parse_listing(text)
    if len(mem) != KNOWN_BYTES:
        raise ValueError('expected %d listed bytes, found %d' % (KNOWN_BYTES, len(mem)))
    full = dict(mem)
    for i, val in enumerate(ID_STRING):
        if ID_ADDRESS + i in mem:
            raise ValueError('identification string overlaps a listed byte')
        full[ID_ADDRESS + i] = val
    image = bytes(full.get(x, 0x00) for x in range(2048))
    check_image(image, 'rebuilt image')
    (dest / '1503033.bin').write_bytes(image)
    (dest / '1503033_known.json').write_text(json.dumps({
        'source': source, 'listing_sha256': LISTING_SHA256,
        'image_sha1': DUMP_SHA1, 'image_sha256': DUMP_SHA256,
        'listed_bytes': len(mem), 'id_string_bytes': len(ID_STRING),
        'zero_fill_bytes': 2048 - len(full), 'gaps': gaps(mem),
        'known': [1 if x in mem else 0 for x in range(2048)],
    }) + '\n')
    if args.dump:
        dump = Path(args.dump).read_bytes()
        check_image(dump, 'supplied dump')
        if dump != image:
            raise ValueError('supplied dump differs from the rebuilt image')
        print('supplied dump matches the rebuilt image', file=sys.stderr)
    print(dest / '1503033.bin')
    return 0


if __name__ == '__main__':
    sys.exit(main())
