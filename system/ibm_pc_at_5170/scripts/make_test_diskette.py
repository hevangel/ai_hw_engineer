#!/usr/bin/env python3
"""Build the IBM PC AT diskette test images (no copyrighted content).

Usage: make_test_diskette.py OUT_DIR [--format 1200|360]

Writes, for the chosen format (default 1200, the 1.2 MB high-capacity
format: 80 cylinders, 2 heads, 15 sectors of 512 bytes; 360 is 40 x 2 x 9):
  blank_<fmt>.img   a formatted, empty FAT12 diskette whose boot sector
                    only halts;
  boot_<fmt>.img    a FAT12 diskette (two reserved sectors: the boot
                    program is two sectors long) with one file, TESTDATA.BIN, filling
                    the data area from cluster 2 up to WRITE_SPARE sectors
                    before the end (pseudo-random bytes from a fixed LCG),
                    and a boot sector assembled from tb/boot_diskette.S
                    with GNU as and ld (the tool image's binutils). The boot
                    program reads the whole file with INT 13h, checks its
                    sum, writes a pattern to the last sector of the diskette
                    (free in the FAT) and reads it back;
  boot_<fmt>.json   the parameters (file LBA and sectors, expected sum,
                    written sector and its expected contents).
The FAT12 layout is the DOS one for the format (BIOS parameter block in the
boot sector, two FATs, a root directory), written from the published
FAT12 structure; nothing is copied from any DOS disk.
"""
import argparse
import json
import struct
import subprocess
import tempfile
from pathlib import Path

FORMATS = {
    # cylinders, heads, spt, media byte, sectors per FAT, root entries
    '1200': (80, 2, 15, 0xF9, 7, 224),
    '360': (40, 2, 9, 0xFD, 2, 112),
}
WRITE_SPARE = 11


def assemble(source):
    with tempfile.TemporaryDirectory() as tmp:
        obj, out = Path(tmp) / 'boot.o', Path(tmp) / 'boot.bin'
        subprocess.run(['as', '--32', '-o', str(obj), str(source)], check=True)
        subprocess.run(['ld', '-m', 'elf_i386', '-Ttext=0x7c00', '--oformat', 'binary',
                        '-o', str(out), str(obj)], check=True)
        code = out.read_bytes()
    if len(code) != 1024 or code[510:512] != b'\x55\xaa':
        raise SystemExit(f'boot program assembled to {len(code)} bytes')
    return bytearray(code)


def bpb(fmt, reserved):
    cyl, heads, spt, media, fat_sectors, root = FORMATS[fmt]
    total = cyl * heads * spt
    return struct.pack('<8sHBHBHHBHHHII', b'ATTEST  ', 512, 1 if fmt == '1200' else 2, reserved, 2, root,
                       total, media, fat_sectors, spt, heads, 0, 0) + \
        struct.pack('<BBBI11s8s', 0, 0, 0x29, 0x19840814, b'AT DISKETTE', b'FAT12   ')


def checksum(data):
    total = 0
    for (word,) in struct.iter_unpack('<H', data):
        total = (((total << 1) | (total >> 15)) & 0xffff)
        total = (total + word) & 0xffff
    return total


def write_fat12(fat, cluster, value):
    offset = cluster * 3 // 2
    pair = fat[offset] | fat[offset + 1] << 8
    if cluster & 1:
        pair = (pair & 0x000f) | (value << 4)
    else:
        pair = (pair & 0xf000) | value
    fat[offset], fat[offset + 1] = pair & 0xff, pair >> 8


def build(fmt, boot_code, with_file):
    cyl, heads, spt, media, fat_sectors, root = FORMATS[fmt]
    total = cyl * heads * spt
    per_cluster = 1 if fmt == '1200' else 2
    image = bytearray(b'\xf6' * (total * 512))   # FORMAT's filler byte
    reserved = len(boot_code) // 512
    sector = bytearray(boot_code[:512])
    header = bpb(fmt, reserved)
    sector[3:3 + len(header)] = header
    root_sectors = root * 32 // 512
    data_lba = reserved + 2 * fat_sectors + root_sectors
    fat = bytearray(fat_sectors * 512)
    fat[0:3] = bytes([media, 0xff, 0xff])
    rootdir = bytearray(root_sectors * 512)
    params = {}
    if with_file:
        file_sectors = (total - data_lba - WRITE_SPARE) // per_cluster * per_cluster
        clusters = file_sectors // per_cluster
        for n in range(clusters):
            write_fat12(fat, 2 + n, 0xfff if n == clusters - 1 else 3 + n)
        state = 0x2545F491
        content = bytearray(file_sectors * 512)
        for i in range(len(content)):
            state = (state * 1103515245 + 12345) & 0xffffffff
            content[i] = state >> 23 & 0xff
        image[data_lba * 512:data_lba * 512 + len(content)] = content
        rootdir[0:32] = struct.pack('<8s3sB10sHHHI', b'TESTDATA', b'BIN', 0x20, bytes(10),
                                    0x6000, 0x110e, 2, len(content))
        write_lba = total - 1
        pattern = bytes(((0x5a + 0x3b * i) & 0xff) for i in range(512))
        params = dict(format=fmt, file_lba=data_lba, file_sectors=file_sectors,
                      file_sum=checksum(content), write_lba=write_lba,
                      write_pattern=pattern.hex(), spt=spt, heads=heads)
        struct.pack_into('<HHHHHH', sector, 62, data_lba, file_sectors, params['file_sum'],
                         write_lba, spt, heads)
    image[0:512] = sector
    image[512:len(boot_code)] = boot_code[512:]
    for copy in range(2):
        start = (reserved + copy * fat_sectors) * 512
        image[start:start + len(fat)] = fat
    start = (reserved + 2 * fat_sectors) * 512
    image[start:start + len(rootdir)] = rootdir
    return image, params


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('out_dir')
    parser.add_argument('--format', choices=sorted(FORMATS), default='1200')
    args = parser.parse_args()
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    source = Path(__file__).resolve().parent.parent / 'tb' / 'boot_diskette.S'
    code = assemble(source)
    halt_only = bytearray(512)
    halt_only[0:3] = b'\xeb\x3c\x90'
    halt_only[62:66] = b'\xfa\xf4\xeb\xfd'      # CLI; HLT; JMP $-1
    halt_only[510:] = b'\x55\xaa'
    blank, _ = build(args.format, halt_only, False)
    boot, params = build(args.format, code, True)
    (out / f'blank_{args.format}.img').write_bytes(blank)
    (out / f'boot_{args.format}.img').write_bytes(boot)
    (out / f'boot_{args.format}.json').write_text(json.dumps(params, indent=1) + '\n')
    print(f'{out}/boot_{args.format}.img: file {params["file_sectors"]} sectors from LBA '
          f'{params["file_lba"]}, sum {params["file_sum"]:04X}, write LBA {params["write_lba"]}')


if __name__ == '__main__':
    main()
