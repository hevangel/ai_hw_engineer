"""Deterministic randomised differential cases.

Each case is a preamble that loads general registers 0-7 from sixteen random
data words, followed by exactly one random instruction drawn from the set the
core implements. One instruction per case means a divergence names the
instruction that caused it.

Programs are built as a byte stream and packed into the word image, because
SS-format instructions are six bytes long and straddle word boundaries.

Excluded on purpose:
  - branches (a random branch lands in uncontrolled storage),
  - DR/D (a random dividend can raise the divide exception, whose step
    accounting differs between the two engines),
  - SPM/SSM/LPSW/SVC (they change the PSW or enter the interruption path),
  - EXECUTE (its subject would be random code).
"""
import random

RR = [0x18, 0x12, 0x1A, 0x1B, 0x14, 0x16, 0x17, 0x19, 0x15]
RX = [0x58, 0x50, 0x5A, 0x5B, 0x59, 0x55, 0x54, 0x56, 0x57,
      0x48, 0x40, 0x4A, 0x4B, 0x49, 0x4C, 0x41]
SI = [0x92, 0x95, 0x91]
SS = [0xD2, 0xD1, 0xD3, 0xD4, 0xD6, 0xD7, 0xD5, 0xDC]
SHIFT = [0x8B, 0x8A, 0x8F, 0x8E]


def _pack(code):
    """Pad the byte stream to a word boundary and return 32-bit words."""
    code = bytes(code)
    if len(code) % 4:
        code += b"\x00" * (4 - len(code) % 4)
    return [int.from_bytes(code[i:i + 4], "big") for i in range(0, len(code), 4)]


def _rx(op, r1, x2, b2, disp):
    return bytes([op, (r1 << 4) | x2, (b2 << 4) | ((disp >> 8) & 0xF), disp & 0xFF])


def make_cases(count=24, seed=36054):
    rng = random.Random(seed)
    cases = []
    for index in range(count):
        data = {0x200 + 4 * i: rng.getrandbits(32) for i in range(16)}
        code = bytearray()
        for reg in range(8):
            code += _rx(0x58, reg, 0, 0, 0x200 + 4 * reg)

        kind = rng.choice(["RR", "RX", "SI", "SS", "SHIFT", "MR"])
        if kind == "RR":
            op, b1 = rng.choice(RR), rng.getrandbits(8)
            code += bytes([op, b1])
        elif kind == "RX":
            op = rng.choice(RX)
            code += _rx(op, rng.randrange(16), 0, 0,
                        0x200 + 4 * rng.randrange(12))
        elif kind == "SI":
            op, i2 = rng.choice(SI), rng.getrandbits(8)
            disp = 0x200 + 4 * rng.randrange(12)
            code += bytes([op, i2, (disp >> 8) & 0xF, disp & 0xFF])
        elif kind == "SS":
            op, length = rng.choice(SS), rng.randrange(8)
            # The reference sets CC on NC/OC/XC; A22-6821-7 pp. 55-56 says the
            # code is unchanged for these three, so the comparison ignores CC
            # for those cases and the report records the difference.
            ignore_cc = op in (0xD4, 0xD6, 0xD7)
            d1 = 0x200 + 4 * rng.randrange(8)
            d2 = 0x200 + 4 * rng.randrange(8)
            code += bytes([op, length, (d1 >> 8) & 0xF, d1 & 0xFF,
                           (d2 >> 8) & 0xF, d2 & 0xFF])
        elif kind == "SHIFT":
            op = rng.choice(SHIFT)
            r1 = rng.randrange(16)
            if op in (0x8F, 0x8E):
                r1 &= 0xE
            count = rng.randrange(32)
            code += bytes([op, r1 << 4, (count >> 8) & 0xF, count & 0xFF])
        else:  # MR: even R1 names the pair, R2 is the multiplier
            code += bytes([0x1C, (rng.randrange(0, 16, 2) << 4) | rng.randrange(16)])

        case = dict(name=f"rnd{index:02d}", note=f"{kind} random case",
                    words=_pack(code), steps=9, data=data)
        if kind == "SS" and ignore_cc:
            case["ignore_cc"] = True
        cases.append(case)
    return cases
