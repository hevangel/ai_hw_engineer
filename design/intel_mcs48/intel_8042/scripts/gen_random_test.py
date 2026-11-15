#!/usr/bin/env python3
"""Generate a random 2K program and host/pin stimulus for lockstep testing.

usage: gen_random_test.py SEED OUT_PREFIX [RETIRES]
Writes OUT_PREFIX.bin and OUT_PREFIX.txt. Opcodes are uniform over all 256
values (so illegal and expander opcodes appear), with a bias toward the
interrupt, timer and DBB instructions so those paths are exercised often.
"""
import random
import sys
from pathlib import Path

BIAS = [0x05, 0x15, 0x25, 0x35, 0x55, 0x45, 0x65, 0x62, 0x42, 0x22, 0x02,
        0x93, 0x83, 0xF5, 0x16, 0xD6, 0x86, 0x90, 0xD7, 0xC7, 0xA3, 0xE3, 0xB3]


def main():
    seed = int(sys.argv[1])
    prefix = Path(sys.argv[2])
    retires = int(sys.argv[3]) if len(sys.argv) > 3 else 20000
    rnd = random.Random(seed)
    rom = bytearray(rnd.randrange(256) for _ in range(2048))
    for _ in range(300):
        rom[rnd.randrange(2048)] = rnd.choice(BIAS)
    lines = ['# random lockstep test seed %d' % seed, 'run %d' % retires]
    idx = 0
    while idx < retires:
        idx += rnd.randrange(1, 400)
        k = rnd.random()
        if k < 0.45:
            lines.append('%d fwrite %d %02X' % (idx, rnd.randrange(2), rnd.randrange(256)))
        elif k < 0.75:
            lines.append('%d read %d' % (idx, rnd.randrange(2)))
        else:
            lines.append('%d pins %02X %02X %d %d' % (
                idx, rnd.randrange(256), rnd.randrange(256),
                rnd.randrange(2), rnd.randrange(2)))
    prefix.with_suffix('.bin').write_bytes(bytes(rom))
    prefix.with_suffix('.txt').write_text('\n'.join(lines) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
