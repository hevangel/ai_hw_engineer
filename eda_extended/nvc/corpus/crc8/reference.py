#!/usr/bin/env python3
"""Independent CRC-8 (poly 0x07, init 0, no reflection) reference for the crc8 corpus case.

Standard check value: CRC-8/SMBUS of "123456789" is 0xF4 (CRC catalogue). Prints the
expected simulator output so it can be diffed against `nvc -r`.
"""
def crc8(data):
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = ((crc << 1) ^ 0x07) & 0xFF if crc & 0x80 else (crc << 1) & 0xFF
    return crc

assert crc8(b"123456789") == 0xF4  # CRC-8/SMBUS check value from the CRC catalogue
print("crc8(123456789)=%02X" % crc8(b"123456789"))
print("crc8(00FFA55A0180)=%02X" % crc8(bytes([0x00, 0xFF, 0xA5, 0x5A, 0x01, 0x80])))
print("crc8(00..FF)=%02X" % crc8(bytes(range(256))))
