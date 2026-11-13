#!/usr/bin/env python3
"""Rebuild the IBM PC AT 8042 firmware (part 1503033) from a pinned listing.

No hash-pinned raw dump of 1503033.bin has a citable public source. A. Tarpai
(Halicery) published a 2010 commented disassembly of the MESS dump, which
prints every disassembled address with its bytes, under the MIT licence. The
repository carries it as the opt-in submodule external/halicery/8042. This
script reads the listing from that submodule (or, if it is not checked out,
downloads the same file at the pinned commit), converts CRLF to LF, checks
its SHA-256, and writes:

  work/firmware/1503033_partial.bin  2048 bytes, unknown bytes = FILL
  work/firmware/1503033_known.json   the known-byte map and gap ranges

The listing covers 1,388 of 2,048 bytes. The rebuilt image is therefore not
the IBM ROM and cannot match MAME's hash for it
(CRC32 5a81c0d2, SHA-1 0100f8789fb4de74706ae7f9473a12ec2b9bd729).
Users who hold a verified dump can pass it with --dump; it is checked against
that SHA-1 and then cross-checked against every listed byte.

Usage: rebuild_1503033.py [--work DIR] [--fill HEX] [--dump PATH]
Prints the path of the image to use.
"""
import argparse
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

REVISION = '6ddf1669224342663ed1fc6e9a33f3577ad9ba02'
SOURCE = '8042_1503033.TXT'
URL = f'https://raw.githubusercontent.com/Halicery/8042/{REVISION}/{SOURCE}'
SUBMODULE = Path(__file__).resolve().parents[4] / 'external' / 'halicery' / '8042'
# SHA-256 of the listing with LF line endings. The PCjs archive copy
# (jeffpar/pcjs 1a91d38e, machines/pcx86/ibm/keyboard/) has the same content.
LISTING_SHA256 = '3e10124dfba23726c2e11c2f50812fd1190828f6dd7bc54a4b4d186d1fa5ca98'
DUMP_SHA1 = '0100f8789fb4de74706ae7f9473a12ec2b9bd729'
KNOWN_BYTES = 1388
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


def main():
    here = Path(__file__).resolve().parents[1]
    ap = argparse.ArgumentParser()
    ap.add_argument('--work', default=str(here / 'work'))
    ap.add_argument('--fill', default='00')
    ap.add_argument('--dump')
    args = ap.parse_args()
    dest = Path(args.work) / 'firmware'
    dest.mkdir(parents=True, exist_ok=True)
    text, source = fetch_listing(dest / '8042_1503033.TXT')
    mem = parse_listing(text)
    if len(mem) != KNOWN_BYTES:
        raise ValueError('expected %d listed bytes, found %d' % (KNOWN_BYTES, len(mem)))
    fill = int(args.fill, 16) & 0xFF
    image = bytes(mem.get(x, fill) for x in range(2048))
    (dest / '1503033_partial.bin').write_bytes(image)
    (dest / '1503033_known.json').write_text(json.dumps({
        'source': source, 'listing_sha256': LISTING_SHA256,
        'known_bytes': len(mem), 'fill': fill, 'gaps': gaps(mem),
        'known': [1 if x in mem else 0 for x in range(2048)],
    }) + '\n')
    if args.dump:
        dump = Path(args.dump).read_bytes()
        if hashlib.sha1(dump).hexdigest() != DUMP_SHA1:
            raise ValueError('dump SHA-1 does not match MAME 1503033.bin')
        bad = [x for x, v in mem.items() if dump[x] != v]
        if bad:
            raise ValueError('dump disagrees with the listing at %s' %
                             ', '.join('%03X' % x for x in bad[:8]))
        print(Path(args.dump).resolve())
        return 0
    print(dest / '1503033_partial.bin')
    return 0


if __name__ == '__main__':
    sys.exit(main())
