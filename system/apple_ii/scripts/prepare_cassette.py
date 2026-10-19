#!/usr/bin/env python3
"""Project exerciser in D0; historical byte routines remain in the original F8."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOAD = bytes.fromhex('00 ff 55 aa a5 5a')


def main():
    code = bytearray()

    def emit(*values):
        code.extend(values)

    def store(address, value):
        emit(0xa9, value, 0x8d, address & 255, address >> 8)

    emit(0x78, 0xd8)  # SEI, CLD: independent of saved Monitor processor state.
    for index, value in enumerate(PAYLOAD):
        store(0x0200 + index, value)
    for address, value in [(0x3c, 0), (0x3d, 2), (0x3e, 5), (0x3f, 2)]:
        store(address, value)
    store(0x02f0, 1)
    emit(0xa9, 0xff, 0x20, 0xd2, 0xfe)  # Original WRITE body, skipping leader.
    store(0x02f0, 2)
    store(0x02f0, 3)  # Input preconditioning, before measuring any data bits.
    emit(0xa2, 0x40, 0xca, 0xd0, 0xfd)  # X=64; DEX/BNE: ~314 us settling.
    store(0x02f0, 4)
    emit(0xad, 0x60, 0xc0, 0x29, 0x80, 0x85, 0x2f)
    for index in range(len(PAYLOAD) + 1):
        emit(0xa0, 0x3b, 0xa9, 0, 0x20, 0xec, 0xfc,
             0x8d, 0x20 + index, 2)  # Original RDBYTE, actual DRAM result.
    for index in range(len(PAYLOAD) + 1):
        emit(0xad, 0x20 + index, 2, 0x8d, 0x40 + index, 2)  # DRAM readback.
    store(0x02f0, 5)
    stop = 0xd000 + len(code)
    emit(0x4c, stop & 255, stop >> 8)
    assert len(code) <= 2048
    (ROOT / 'work/cassette_D0.hex').write_text(
        ''.join(f'{b:02x}\n' for b in code + bytes([0xea]) * (2048 - len(code))),
        encoding='ascii')
    checksum = 0xff
    for value in PAYLOAD:
        checksum ^= value
    (ROOT / 'work/cassette_expected.hex').write_text(
        ''.join(f'{b:02x}\n' for b in PAYLOAD + bytes([checksum])), encoding='ascii')
    print(f'Prepared D0 exerciser ({len(code)} bytes), original WRITE checksum {checksum:02x}')


if __name__ == '__main__':
    main()
