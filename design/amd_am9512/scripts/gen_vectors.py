#!/usr/bin/env python3
"""Independent Am9512 reference model and test-vector generator.

The model is written from the 1980 AMD Am9500 guide chapter, not from the RTL.
It implements the same documented stack and format rules and is used to generate
vectors for the top-level testbench.  It is intentionally independent of the
SystemVerilog implementation.
"""
from __future__ import annotations

import argparse
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "work" / "vectors.txt"

SINGLE = dict(mant=24, exp=8, bias=127)
DOUBLE = dict(mant=53, exp=11, bias=1023)


def mask(width: int) -> int:
    return (1 << width) - 1


def unpack(word: int, fmt: dict) -> tuple[int, int, int, bool]:
    exp_w = fmt["exp"]
    frac_w = fmt["mant"] - 1
    exp = (word >> frac_w) & mask(exp_w)
    frac = word & mask(frac_w)
    sign = (word >> (exp_w + frac_w)) & 1
    zero = exp == 0
    mant = 0 if zero else (1 << frac_w) | frac
    return sign, exp, mant, zero


def pack(sign: int, exp: int, mant: int, fmt: dict) -> tuple[int, int, int, int, int]:
    """Return (word, S, Z, U, V, D)."""
    exp_w = fmt["exp"]
    frac_w = fmt["mant"] - 1
    max_exp = mask(exp_w)
    if mant == 0:
        return 0, 0, 1, 0, 0, 0
    if exp < 1:
        return 0, 0, 1, 1, 0, 0
    if exp > max_exp:
        word = (sign << (exp_w + frac_w)) | ((exp & max_exp) << frac_w) | (mant & mask(frac_w))
        return word, sign, 0, 0, 1, 0
    word = (sign << (exp_w + frac_w)) | (exp << frac_w) | (mant & mask(frac_w))
    return word, sign, 0, 0, 0, 0


def round_pack(acc: int, exp: int, sign: int, fmt: dict) -> tuple[int, int, int, int, int]:
    mant_w = fmt["mant"]
    rounded = acc + 4
    if (rounded & 0x7) == 0:
        rounded &= ~0x8
    if (rounded >> (mant_w + 3)) & 1:
        rounded >>= 1
        exp += 1
    mant = (rounded >> 3) & mask(mant_w)
    return pack(sign, exp, mant, fmt)


def zero_result() -> tuple[int, int, int, int, int, int]:
    return 0, 0, 1, 0, 0, 0


def add_sub(a: int, b: int, subtract: bool, fmt: dict) -> tuple[int, int, int, int, int, int]:
    sa, ea, ma, a_zero = unpack(a, fmt)
    sb, eb, mb, b_zero = unpack(b, fmt)
    if subtract:
        sa ^= 1
    if a_zero and b_zero:
        return zero_result()
    if a_zero:
        w, s, z, u, v, d = pack(sb, eb, mb, fmt)
        return w, s, z, u, v, 0
    if b_zero:
        w, s, z, u, v, d = pack(sa, ea, ma, fmt)
        return w, s, z, u, v, 0
    acc_w = fmt["mant"] + 3
    if ea >= eb:
        exp_max, x, y = ea, ma, mb
        xs, ys = sa, sb
        shift = ea - eb
    else:
        exp_max, x, y = eb, mb, ma
        xs, ys = sb, sa
        shift = eb - ea
    x_ext = x << 3
    y_full = y << 3
    if shift == 0:
        y_ext, sticky = y_full, 0
    elif shift >= acc_w:
        y_ext, sticky = 0, int(y_full != 0)
    else:
        y_ext = y_full >> shift
        sticky = int((y_full & mask(shift)) != 0)
    if xs == ys:
        total = x_ext + y_ext
        sign = xs
    elif x_ext >= y_ext:
        total = x_ext - y_ext
        sign = xs
    else:
        total = y_ext - x_ext
        sign = ys
    if total == 0:
        return zero_result()
    if (total >> acc_w) & 1:
        sticky |= total & 1
        total >>= 1
        exp_max += 1
    lead = total.bit_length() - 1
    if lead < fmt["mant"] + 2:
        norm = fmt["mant"] + 2 - lead
        total <<= norm
        exp_max -= norm
    elif lead > fmt["mant"] + 2:
        norm = lead - (fmt["mant"] + 2)
        sticky |= int((total & mask(norm)) != 0)
        total >>= norm
        exp_max += norm
    return round_pack(total, exp_max, sign, fmt)


def multiply(a: int, b: int, fmt: dict) -> tuple[int, int, int, int, int, int]:
    sa, ea, ma, a_zero = unpack(a, fmt)
    sb, eb, mb, b_zero = unpack(b, fmt)
    if a_zero or b_zero:
        return zero_result()
    prod = ma * mb
    exp = ea + eb - 2 * fmt["bias"]
    lead = prod.bit_length() - 1
    exp += lead - (2 * fmt["mant"] - 2)
    mant_w = fmt["mant"]
    sig = (prod >> (lead - (mant_w - 1))) & mask(mant_w)
    high = lead - mant_w
    guard = (prod >> high) & 1 if high >= 0 else 0
    rnd = (prod >> (high - 1)) & 1 if high - 1 >= 0 else 0
    sticky = int((prod & mask(high - 1)) != 0) if high - 2 >= 0 else 0
    acc = (sig << 3) | (guard << 2) | (rnd << 1) | sticky
    return round_pack(acc, exp + fmt["bias"], sa ^ sb, fmt)


def divide(a: int, b: int, fmt: dict) -> tuple[int, int, int, int, int, int]:
    sa, ea, ma, a_zero = unpack(a, fmt)
    sb, eb, mb, b_zero = unpack(b, fmt)
    if a_zero:
        w, s, z, u, v, d = pack(sb, eb, mb, fmt)
        return w, s, z, u, v, 1
    if b_zero:
        return zero_result()
    exp = eb - ea
    numerator = mb << (fmt["mant"] + 3)
    q, rem = divmod(numerator, ma)
    lead = q.bit_length() - 1
    exp += lead - (fmt["mant"] + 3)
    mant_w = fmt["mant"]
    sig = (q >> (lead - (mant_w - 1))) & mask(mant_w)
    high = lead - mant_w
    guard = (q >> high) & 1 if high >= 0 else 0
    rnd = (q >> (high - 1)) & 1 if high - 1 >= 0 else 0
    sticky = int(rem != 0)
    if high - 2 >= 0:
        sticky |= int((q & mask(high - 1)) != 0)
    acc = (sig << 3) | (guard << 2) | (rnd << 1) | sticky
    return round_pack(acc, exp + fmt["bias"], sa ^ sb, fmt)


def to_bytes(word: int, width: int) -> bytes:
    return word.to_bytes(width, "big")


def from_bytes(data: bytes) -> int:
    return int.from_bytes(data, "big")


def stack_after(op: int, stack: bytes, fmt: dict) -> tuple[bytes, int]:
    """Return the documented final 16-byte stack and status byte."""
    if op in (0x01, 0x02, 0x03, 0x04):
        width = 4
        a = from_bytes(stack[0:4])
        b = from_bytes(stack[4:8])
        if op == 0x01:
            r, s, z, u, v, d = add_sub(a, b, False, fmt)
        elif op == 0x02:
            r, s, z, u, v, d = add_sub(a, b, True, fmt)
        elif op == 0x03:
            r, s, z, u, v, d = multiply(a, b, fmt)
        else:
            r, s, z, u, v, d = divide(a, b, fmt)
        return to_bytes(r, width) + stack[8:] + bytes(4), (s << 6) | (z << 5) | (d << 3) | (u << 2) | (v << 1)
    if op in (0x29, 0x2A, 0x2B, 0x2C):
        width = 8
        a = from_bytes(stack[0:8])
        b = from_bytes(stack[8:16])
        if op == 0x29:
            r, s, z, u, v, d = add_sub(a, b, False, fmt)
        elif op == 0x2A:
            r, s, z, u, v, d = add_sub(a, b, True, fmt)
        elif op == 0x2B:
            r, s, z, u, v, d = multiply(a, b, fmt)
        else:
            r, s, z, u, v, d = divide(a, b, fmt)
        return to_bytes(r, width) + bytes(8), (s << 6) | (z << 5) | (d << 3) | (u << 2) | (v << 1)

    def status_of(word: bytes, double: bool) -> int:
        if double:
            value = from_bytes(word[0:8])
            exp = (value >> (fmt["mant"] - 1)) & mask(fmt["exp"])
            sign = (value >> (fmt["mant"] - 1 + fmt["exp"])) & 1
        else:
            value = from_bytes(word[0:4])
            exp = (value >> (fmt["mant"] - 1)) & mask(fmt["exp"])
            sign = (value >> (fmt["mant"] - 1 + fmt["exp"])) & 1
        zero = exp == 0
        return ((0 if zero else sign) << 6) | ((1 if zero else 0) << 5)

    if op == 0x00:
        return stack, 0
    if op == 0x05:
        tos = bytearray(stack[0:4])
        exp = (from_bytes(tos) >> 23) & 0xFF
        if exp == 0:
            tos = bytearray(4)
        else:
            tos[0] ^= 0x80
        return bytes(tos) + stack[4:], status_of(tos, False)
    if op == 0x2D:
        tos = bytearray(stack[0:8])
        exp = (from_bytes(tos) >> 52) & 0x7FF
        if exp == 0:
            tos = bytearray(8)
        else:
            tos[0] ^= 0x80
        return bytes(tos) + stack[8:], status_of(tos, True)
    if op == 0x06:
        tos = bytearray(stack[0:4])
        exp = (from_bytes(tos) >> 23) & 0xFF
        new_tos = bytearray(4) if exp == 0 else tos
        return bytes(new_tos) + bytes(tos) + stack[4:12], status_of(new_tos, False)
    if op == 0x2E:
        tos = stack[0:8]
        return tos + tos, status_of(tos, True)
    if op == 0x07:
        return stack[4:] + stack[0:4], status_of(stack[4:8], False)
    if op == 0x2F:
        return stack[8:] + stack[0:8], status_of(stack[8:16], True)
    if op == 0x08:
        return stack[4:8] + stack[0:4] + stack[8:], status_of(stack[4:8], False)
    raise ValueError(f"not a data op: {op:#x}")


def random_word(fmt: dict, rng: random.Random, allow_zero: bool = True) -> int:
    exp_w = fmt["exp"]
    if allow_zero and rng.random() < 0.08:
        return 0
    exp = rng.randint(1, mask(exp_w) - 1)
    # Bias the exponent toward the middle to exercise alignment and rounding.
    if rng.random() < 0.35:
        exp = max(1, min(mask(exp_w) - 1, fmt["bias"] + rng.randint(-6, 6)))
    frac = rng.getrandbits(fmt["mant"] - 1)
    sign = rng.getrandbits(1)
    return (sign << (exp_w + fmt["mant"] - 1)) | (exp << (fmt["mant"] - 1)) | frac


def directed_vectors() -> list[tuple[int, bytes, str]]:
    cases: list[tuple[int, bytes, str]] = []
    one_s = 0x3F800000
    two_s = 0x40000000
    half_s = 0x3F000000
    one_d = 0x3FF0000000000000
    two_d = 0x4000000000000000
    half_d = 0x3FE0000000000000
    small_s = 0x00000001
    small_d = 0x0000000000000001
    big_s = 0x7F7FFFFF
    big_d = 0x7FEFFFFFFFFFFFFF

    singles = [
        ("1+2", 0x01, one_s, two_s),
        ("2-1", 0x02, one_s, two_s),
        ("1-1", 0x02, one_s, one_s),
        ("1*2", 0x03, one_s, two_s),
        ("2/1", 0x04, one_s, two_s),
        ("1/2", 0x04, two_s, one_s),
        ("zero+1", 0x01, 0, one_s),
        ("1-zero", 0x01, one_s, 0),
        ("zero-zero", 0x01, 0, 0),
        ("zero*1", 0x03, 0, one_s),
        ("1/zero", 0x04, one_s, 0),
        ("zero/1", 0x04, 0, one_s),
        ("neg+pos", 0x01, 0xBF800000, one_s),
        ("carry", 0x01, big_s, one_s),
        ("tiny", 0x01, small_s, small_s),
        ("tiny*2", 0x03, small_s, two_s),
        ("tiny/tiny", 0x04, small_s, small_s),
        ("round-half-even", 0x01, 0x3F800001, 0x00000001),
    ]
    for name, op, a, b in singles:
        stack = to_bytes(a, 4) + to_bytes(b, 4) + bytes(8)
        cases.append((op, stack, f"S {name}"))

    doubles = [
        ("1+2", 0x29, one_d, two_d),
        ("2-1", 0x2A, one_d, two_d),
        ("1-1", 0x2A, one_d, one_d),
        ("1*2", 0x2B, one_d, two_d),
        ("2/1", 0x2C, one_d, two_d),
        ("1/2", 0x2C, two_d, one_d),
        ("zero+1", 0x29, 0, one_d),
        ("1-zero", 0x29, one_d, 0),
        ("zero*1", 0x2B, 0, one_d),
        ("1/zero", 0x2C, one_d, 0),
        ("zero/1", 0x2C, 0, one_d),
        ("neg+pos", 0x29, 0xBFF0000000000000, one_d),
        ("carry", 0x29, big_d, one_d),
        ("tiny", 0x29, small_d, small_d),
        ("tiny*2", 0x2B, small_d, two_d),
        ("tiny/tiny", 0x2C, small_d, small_d),
    ]
    for name, op, a, b in doubles:
        stack = to_bytes(a, 8) + to_bytes(b, 8)
        cases.append((op, stack, f"D {name}"))

    # Data manipulation and CLR, including the documented zero special cases.
    cases.extend([
        (0x00, bytes(range(16)), "CLR"),
        (0x05, to_bytes(0xBF800000, 4) + bytes(12), "CHSS neg"),
        (0x05, to_bytes(0x3F800000, 4) + bytes(12), "CHSS pos"),
        (0x05, bytes(16), "CHSS zero"),
        (0x2D, to_bytes(0xBFF0000000000000, 8) + bytes(8), "CHSD neg"),
        (0x2D, to_bytes(0x3FF0000000000000, 8) + bytes(8), "CHSD pos"),
        (0x2D, bytes(16), "CHSD zero"),
        (0x06, to_bytes(0x3F800000, 4) + to_bytes(0x40000000, 4) + bytes(8), "PTOS"),
        (0x06, bytes(4) + to_bytes(0x40000000, 4) + bytes(8), "PTOS zero TOS"),
        (0x2E, to_bytes(0x3FF0000000000000, 8) + to_bytes(0x4000000000000000, 8), "PTOD"),
        (0x07, to_bytes(0x3F800000, 4) + to_bytes(0x40000000, 4) + bytes(8), "POPS"),
        (0x2F, to_bytes(0x3FF0000000000000, 8) + to_bytes(0x4000000000000000, 8), "POPD"),
        (0x08, to_bytes(0x3F800000, 4) + to_bytes(0x40000000, 4) + bytes(8), "XCHS"),
    ])
    return cases


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--random", type=int, default=400)
    parser.add_argument("--seed", type=int, default=9512)
    args = parser.parse_args()
    rng = random.Random(args.seed)
    rows: list[tuple[int, bytes, str]] = directed_vectors()
    for _ in range(args.random):
        fmt = SINGLE if rng.random() < 0.5 else DOUBLE
        ops = [0x01, 0x02, 0x03, 0x04] if fmt is SINGLE else [0x29, 0x2A, 0x2B, 0x2C]
        op = rng.choice(ops)
        a = random_word(fmt, rng)
        b = random_word(fmt, rng)
        width = 4 if fmt is SINGLE else 8
        stack = bytearray(rng.getrandbits(8) for _ in range(16))
        stack[0:width] = to_bytes(a, width)
        stack[width:2 * width] = to_bytes(b, width)
        rows.append((op, bytes(stack), f"R {op:#04x}"))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8") as handle:
        for op, stack, name in rows:
            fmt = SINGLE if op < 0x20 else DOUBLE
            expected, status = stack_after(op, stack, fmt)
            handle.write(f"{op:02x} {stack.hex()} {expected.hex()} {status:02x} {name}\n")
    print(f"wrote {len(rows)} vectors to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())