#!/usr/bin/env python3
"""Fetch and verify the IBM PS/2 Display Adapter BIOS ROM (ISA VGA).

usage: get_rom.py [WORK_DIR]          (default: design/ibm_vga/work)

The ROM is IBM's copyrighted firmware. It is downloaded into the ignored
WORK_DIR/firmware/ folder and never committed. The script:

1. downloads the 86Box ROM-set file video/vga/ibm_vga.bin (pinned commit)
   unless it is present;
2. checks its size, SHA-256, SHA-1 and CRC32;
3. rotates it by 8 KB (the option ROM first, then the 8 KB of 00h the file
   starts with) and checks the result against MAME's ROM entry
   "ibm-vga.bin" in src/devices/bus/isa/vga.cpp (CRC32 74e3fadb, SHA-1
   dce64914...; MAME flags it BAD_DUMP);
4. checks the option-ROM header (55 AA 30 = 24 KB), the 8-bit checksum over
   those 24 KB, the sign-on text and the VIDEO_PARMS table shape;
5. writes WORK_DIR/firmware/vga_rom.bin (the 32 KB window C0000h-C7FFFh in
   CPU order: ROM, then 00h, spec V22) and vga_rom.hex ($readmemh image
   for src/vga_rom.sv).

What is *not* cross-checked: no IBM document prints this ROM, its part
number or its checksum; the two dumps above are the same bytes and may
come from one physical read. That it is the PS/2 Display Adapter's ROM
rests on the emulators' naming and on the ROM's own use of the adapter's
46E8h/102h setup ports.
"""
import hashlib
import os
import sys
import urllib.request
import zlib

COMMIT_86BOX = '1ac40f28aa01d2aa159eee81a7bb3eae4b149e9a'
URL = 'https://raw.githubusercontent.com/86Box/roms/%s/video/vga/ibm_vga.bin' % COMMIT_86BOX
SIZE = 32768
SHA256 = '51b49761f72780a696c36f3d2e74a8168c1c99b865070f7f90b8e621a8b5ae17'
SHA1 = '7b8b0e22ecd002d43d5ed1bb9f9a63d9b9948032'
CRC = 0x03b3f90d
# MAME src/devices/bus/isa/vga.cpp, commit 8be57cdc5f44: ROM_LOAD("ibm-vga.bin",
# 0x00000, 0x8000, BAD_DUMP CRC(74e3fadb) SHA1(dce6491424f1726203776dfae9a967a98a4ba7b5))
MAME_CRC = 0x74e3fadb
MAME_SHA1 = 'dce6491424f1726203776dfae9a967a98a4ba7b5'
OFFSET = 0x2000               # 86Box rom_init(..., 0xc0000, 0x8000, 0x7fff, 0x2000, ...)
SIGNON = b'8222554 (C)COPYRIGHT IBM Corp. 1984, 1986 10/27/86'
TABLE, ENTRIES = 0x1342, 29


def fail(msg):
    print('FAIL: ' + msg)
    sys.exit(1)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    work = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, 'work')
    fw = os.path.join(work, 'firmware')
    os.makedirs(fw, exist_ok=True)
    src = os.path.join(fw, 'ibm_vga.bin')
    if not os.path.exists(src):
        print('downloading ' + URL)
        with urllib.request.urlopen(URL, timeout=60) as r:
            data = r.read()
        with open(src, 'wb') as f:
            f.write(data)
    d = open(src, 'rb').read()
    if len(d) != SIZE:
        fail('size %d, expected %d' % (len(d), SIZE))
    h = (hashlib.sha256(d).hexdigest(), hashlib.sha1(d).hexdigest(), zlib.crc32(d))
    print('86Box ibm_vga.bin: %d bytes SHA-256 %s SHA-1 %s CRC32 %08x' % ((len(d),) + h))
    if h != (SHA256, SHA1, CRC):
        fail('86Box file hash mismatch')
    if any(d[:OFFSET]):
        fail('86Box file: bytes 0000-1FFFh are not all zero')
    win = d[OFFSET:] + d[:OFFSET]
    ws, wc = hashlib.sha1(win).hexdigest(), zlib.crc32(win)
    print('rotated by 8 KB (ROM first): SHA-1 %s CRC32 %08x' % (ws, wc))
    if (ws, wc) != (MAME_SHA1, MAME_CRC):
        fail('rotated image does not equal MAME ibm-vga.bin')
    print('equals MAME isa/vga.cpp "ibm-vga.bin" (CRC 74e3fadb, flagged BAD_DUMP by MAME)')
    if win[0:2] != b'\x55\xaa' or win[2] != 0x30:
        fail('option ROM header (expected 55 AA 30)')
    rom = win[:win[2] * 512]
    if sum(rom) & 0xFF:
        fail('option ROM checksum %02x' % (sum(rom) & 0xFF))
    print('option ROM header 55 AA, length %d x 512 = %d bytes, checksum 00' % (win[2], len(rom)))
    if win[3] != 0xEB or win[5:5 + 4] != b'7400' or win[9:9 + len(SIGNON)] != SIGNON:
        fail('sign-on text')
    print('sign-on at 0005h: %r' % win[5:9 + len(SIGNON)].decode())
    for n in range(ENTRIES):
        e = win[TABLE + 64 * n: TABLE + 64 * n + 64]
        if n == 9:
            continue                      # empty slot
        if e[0] not in (40, 80) or e[1] not in (0x00, 0x18, 0x1D):
            fail('VIDEO_PARMS entry %02X columns/rows %d/%d' % (n, e[0], e[1]))
    print('VIDEO_PARMS at %04Xh: %d entries of 64 bytes' % (TABLE, ENTRIES))
    with open(os.path.join(fw, 'vga_rom.bin'), 'wb') as f:
        f.write(win)
    hexf = os.path.join(fw, 'vga_rom.hex')
    with open(hexf, 'w') as f:
        f.write('// IBM PS/2 Display Adapter BIOS, C0000h-C7FFFh CPU order; do not commit\n')
        for i in range(0, SIZE, 16):
            f.write(' '.join('%02x' % b for b in win[i:i + 16]) + '\n')
    print('wrote ' + hexf)
    print('PASS: ROM verified')


if __name__ == '__main__':
    main()
