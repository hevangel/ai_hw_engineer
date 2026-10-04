"""HDLC oracle using Python's independently maintained C CRC implementation.

RFC 1662 sections 5/C specify the reflected CCITT FCS, init/complement,
LSB-first bits and five-one stuffing. binascii.crc_hqx is MSB-first: reflect
each input byte and the result to obtain the RFC form. This is independent of
the RTL bit-at-a-time feedback implementation. No RTL is read by this script.
"""
from pathlib import Path
import binascii
import random

ROOT = Path(__file__).resolve().parents[1]


def reverse(value, width):
    return int(f"{value:0{width}b}"[::-1], 2)


def fcs(data):
    reflected = bytes(reverse(b, 8) for b in data)
    return reverse(binascii.crc_hqx(reflected, 0xffff), 16) ^ 0xffff


def frame(body, corrupt=False):
    check = fcs(body) ^ int(corrupt)
    content = body + check.to_bytes(2, "little")
    assert corrupt or fcs(content) == (0xf0b8 ^ 0xffff)
    flag = [int(b) for b in "01111110"]
    bits, ones = list(flag), 0
    for byte in content:
        for i in range(8):
            b = (byte >> i) & 1
            bits.append(b)
            ones = ones + 1 if b else 0
            if ones == 5:
                bits.append(0)
                ones = 0
    return bits + flag


def main():
    # Published CRC-16/IBM-SDLC check value, also consistent with RFC C.
    assert fcs(b"123456789") == 0x906e
    rng = random.Random(8273)
    bodies = [bytes([0xff, 0x03]) + b"123456789",
              bytes([0xff, 0xff]), bytes([0x7e, 0xf8, 0xff, 0xff, 0x7e, 0]),
              bytes([0x42, 0x13]) + bytes(range(256))]
    for length in [1, 2, 3, 7, 8, 15, 16, 31, 32, 63]:
        for pattern in [0, 0xff, 0x7e, None]:
            bodies.append(bytes([0x42, 0x13]) + bytes(
                rng.randrange(256) if pattern is None else pattern for _ in range(length)))
    lines = []
    for body in bodies:
        bits = frame(body)
        bad = frame(body, True)
        lines.append(f"{len(body)} {len(bits)} {len(bad)}\n" +
                     " ".join(f"{b:02x}" for b in body) + "\n" +
                     " ".join(map(str, bits)) + "\n" +
                     " ".join(map(str, bad)) + "\n")
    (ROOT / "references" / "frames.txt").write_bytes("".join(lines).encode())
    # Boundary-length regression: generated into ignored work, not a large
    # checked-in trace. The first word is bit count; remaining words are LSB first.
    long_body = bytes([0x42, 0x13]) + bytes((i * 7) & 255 for i in range(65535))
    bits = frame(long_body)
    words = [len(bits)] + [sum(b << j for j, b in enumerate(bits[i:i+32]))
                          for i in range(0, len(bits), 32)]
    words.extend([0] * (20000 - len(words)))
    long_path = ROOT / "work" / "sim" / "long_wire.hex"
    long_path.parent.mkdir(parents=True, exist_ok=True)
    long_path.write_bytes("".join(f"{w:08x}\n" for w in words).encode())
    print(f"8273 independent vectors: {len(bodies)} frames")


if __name__ == "__main__":
    main()
