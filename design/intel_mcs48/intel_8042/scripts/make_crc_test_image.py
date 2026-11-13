#!/usr/bin/env python3
"""Build a TEST image from the partial 1503033 rebuild whose self-test CRC is
zero, so the core can be driven past the AAh self-test.

This is NOT the IBM firmware. The 660 bytes missing from the PCjs listing are
filled with 00h and the two gap bytes BAL (7FCh-7FDh) are solved so that the
firmware's own ROM CRC (listing 0754h-07A8h, R6:R7 must be 0000h) passes.
Every listed byte is unchanged. The CRC routine uses only XOR, AND with
constants, rotates and exchanges, so its result is affine over GF(2) in the
ROM bits; 17 runs of the reference model give the linear system.

usage: make_crc_test_image.py PARTIAL.bin KNOWN.json OUT.bin
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from upi42_iss import UPI42   # noqa: E402

BAL = (0x7FC, 0x7FD)
CRC_DONE = 0x7A2          # MOV A,R6 after the CRC loop


def crc_of(rom):
    m = UPI42(bytes(rom))
    m.reset()
    for _ in range(2000):          # boot to the command wait loop
        m.step()
    m.host_write(1, 0xAA)
    for _ in range(400000):
        if m.pc == CRC_DONE:
            return (m.ram[6] << 8) | m.ram[7]
        m.step()
    raise RuntimeError('self-test CRC loop not reached')


def main():
    rom = bytearray(Path(sys.argv[1]).read_bytes())
    known = json.loads(Path(sys.argv[2]).read_text())['known']
    for x in range(2048):
        if not known[x]:
            rom[x] = 0
    for x in BAL:
        if known[x]:
            raise ValueError('balance byte %03X is a listed byte' % x)
    base = crc_of(rom)
    cols = []
    for bit in range(16):
        trial = bytearray(rom)
        trial[BAL[bit // 8]] ^= 1 << (bit % 8)
        cols.append(crc_of(trial) ^ base)
    # Solve sum(x_i * cols[i]) = base over GF(2) by elimination.
    rows = [(cols[i], 1 << i) for i in range(16)]
    sol, target = 0, base
    basis = []
    for vec, tag in rows:
        for bv, bt in basis:
            if vec ^ bv < vec:
                vec ^= bv
                tag ^= bt
        if vec:
            basis.append((vec, tag))
            basis.sort(reverse=True)
    for bv, bt in sorted(basis, reverse=True):
        if target ^ bv < target:
            target ^= bv
            sol ^= bt
    if target:
        raise RuntimeError('CRC cannot be balanced with the chosen bytes')
    rom[BAL[0]] ^= sol & 0xFF
    rom[BAL[1]] ^= sol >> 8
    if crc_of(rom) != 0:
        raise RuntimeError('balanced image does not give CRC 0000')
    Path(sys.argv[3]).write_bytes(bytes(rom))
    print('%s: balance bytes %03X=%02X %03X=%02X' %
          (sys.argv[3], BAL[0], rom[BAL[0]], BAL[1], rom[BAL[1]]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
