#!/usr/bin/env python3
"""Fetch and verify the IBM EGA BIOS ROM (IBM part 6277356, U44, 27128).

usage: get_rom.py [WORK_DIR]          (default: design/ibm_ega/work)

The ROM is IBM's copyrighted firmware. It is downloaded into the ignored
WORK_DIR/firmware/ folder and never committed. The script:

1. downloads the 86Box ROM-set dump (pinned commit) unless it is present;
2. checks size, SHA-256, SHA-1 and CRC32 of that dump;
3. builds the image as stored in the EPROM itself and checks it against
   MAME's ROM entry "6277356.u44" (CRC32 dc146448, SHA-1 dc0794...);
4. checks the option-ROM header, the 8-bit checksum, the sign-on text and
   the first VIDEO_PARMS entry against the BIOS listing in the IBM
   technical reference (values transcribed from the zoomed listing page);
5. writes WORK_DIR/firmware/ega_u44_chip.hex, a $readmemh image of the
   EPROM in chip order, which src/ega_rom.sv loads through ROM_FILE.

Byte order. The 86Box dump is in CPU order: offset 0 holds 55h AAh, as the
processor sees it at C0000h. MAME's dump is the same 16 KB in reverse
order. The logic diagram (sheet 1 and sheet 4) explains this: the EPROM's
address pins A0-A13 are wired to the inverted slot address lines A0-A13
(outputs of the LS04 inverters U45/U46/U47), so CPU offset a reads EPROM
location (a XOR 3FFFh) = 3FFFh - a. A programmer reading the chip gets
the reversed image. ega_rom.sv models that wiring: it holds the chip image
and inverts the address.
"""
import hashlib
import os
import sys
import urllib.request
import zlib

COMMIT_86BOX = '1ac40f28aa01d2aa159eee81a7bb3eae4b149e9a'
URL = ('https://raw.githubusercontent.com/86Box/roms/%s/video/ega/'
       'ibm_6277356_ega_card_u44_27128.bin' % COMMIT_86BOX)
SIZE = 16384
CPU_SHA256 = 'bf1583dd387d6e078ab3f5039bcb3f7020a66a63d5f0e57039883c5081dbbf9c'
CPU_SHA1 = '3af56105530366669a8905c14439619bf6b76b25'
CPU_CRC32 = 0x2f2fbc40
# MAME src/devices/bus/isa/ega.cpp ROM_START(ega): ROMX_LOAD("6277356.u44",
# 0x0000, 0x4000, CRC(dc146448) SHA1(dc0794499b3e499c5777b3aa39554bbf0f2cc19b))
MAME_CRC32 = 0xdc146448
MAME_SHA1 = 'dc0794499b3e499c5777b3aa39554bbf0f2cc19b'

# BIOS listing (IBM EGA technical reference, PDF page 122, lines 1787-1819):
# VIDEO_PARMS at 0717h, mode 0 entry, 64 bytes.
LISTING_0717 = bytes([
    0x28, 0x18, 0x08, 0x00, 0x08,             # DB 40D,24D,08D / DW 0800H
    0x0B, 0x03, 0x00, 0x03,                   # SEQ_PARMS
    0x23,                                     # miscellaneous output
    0x37, 0x27, 0x2D, 0x37, 0x31, 0x15,       # CRT_PARMS
    0x04, 0x11, 0x00, 0x07, 0x06, 0x07,
    0x00, 0x00, 0x00, 0x00, 0xE1, 0x24,
    0xC7, 0x14, 0x08, 0xE0, 0xF0, 0xA3,
    0xFF,
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05,       # ATTR_PARMS
    0x06, 0x07, 0x10, 0x11, 0x12, 0x13,
    0x14, 0x15, 0x16, 0x17, 0x08, 0x00,
    0x0F, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x10,       # GRAPH_PARMS
    0x0E, 0x00, 0xFF])
# Listing lines 606-613 (PDF page 112): JMP SHORT L1, DB '2400',
# DB '6277356 (C)COPYRIGHT IBM 1984', DB '9/13/84'.
SIGNON = b'2400' + b'6277356 (C)COPYRIGHT IBM 1984' + b'9/13/84'


def fail(msg):
    print('FAIL: ' + msg)
    sys.exit(1)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    work = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, 'work')
    fw = os.path.join(work, 'firmware')
    os.makedirs(fw, exist_ok=True)
    cpu_path = os.path.join(fw, 'ega_u44.bin')
    if not os.path.exists(cpu_path):
        print('downloading ' + URL)
        with urllib.request.urlopen(URL, timeout=60) as r:
            data = r.read()
        with open(cpu_path, 'wb') as f:
            f.write(data)
    cpu = open(cpu_path, 'rb').read()
    if len(cpu) != SIZE:
        fail('size %d, expected %d' % (len(cpu), SIZE))
    sha256 = hashlib.sha256(cpu).hexdigest()
    sha1 = hashlib.sha1(cpu).hexdigest()
    crc = zlib.crc32(cpu)
    print('86Box dump (CPU order): %d bytes SHA-256 %s SHA-1 %s CRC32 %08x'
          % (len(cpu), sha256, sha1, crc))
    if (sha256, sha1, crc) != (CPU_SHA256, CPU_SHA1, CPU_CRC32):
        fail('86Box dump hash mismatch')
    chip = cpu[::-1]
    csha1 = hashlib.sha1(chip).hexdigest()
    ccrc = zlib.crc32(chip)
    print('EPROM order (CPU offset XOR 3FFFh): SHA-1 %s CRC32 %08x' % (csha1, ccrc))
    if (csha1, ccrc) != (MAME_SHA1, MAME_CRC32):
        fail('chip-order image does not match MAME 6277356.u44')
    print('agrees with MAME ega.cpp 6277356.u44 (CRC dc146448), which MAME reverses at load')
    if cpu[0:2] != b'\x55\xaa' or cpu[2] != SIZE // 512:
        fail('option ROM header')
    if sum(cpu) & 0xFF:
        fail('option ROM checksum %02x' % (sum(cpu) & 0xFF))
    print('option ROM header 55 AA, length %d x 512, checksum 00' % cpu[2])
    if cpu[3:5] != b'\xeb\x28' or cpu[5:5 + len(SIGNON)] != SIGNON:
        fail('sign-on text differs from listing lines 606-613')
    print('sign-on at 0005h: %r' % cpu[5:5 + len(SIGNON)].decode())
    if cpu[0x717:0x717 + 64] != LISTING_0717:
        fail('VIDEO_PARMS mode 0 entry differs from listing lines 1787-1819')
    print('VIDEO_PARMS 0717h mode 0 entry equals listing (64 bytes)')
    hexf = os.path.join(fw, 'ega_u44_chip.hex')
    with open(hexf, 'w') as f:
        f.write('// IBM EGA BIOS 6277356 (U44), EPROM order; do not commit\n')
        for i in range(0, SIZE, 16):
            f.write(' '.join('%02x' % b for b in chip[i:i + 16]) + '\n')
    print('wrote ' + hexf)
    print('PASS: ROM verified')


if __name__ == '__main__':
    main()
