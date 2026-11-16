#!/usr/bin/env python3
"""Seeded random bench script for the IBM EGA lockstep bench.

usage: gen_random_test.py SEED OUT.txt [OPS]

The script starts from power-on, programs a random small display geometry
(so that frames, retraces and interrupts happen within the run) and then
issues OPS random operations: register writes to every decoded port with
random index and data (including undocumented indices and AEN-high
cycles), I/O reads of decoded and undecoded ports, processor memory writes
and reads in every window and the ROM, DMA-refresh (DACK0) cycles, RESET
DRV pulses, switch/jumper/feature/light-pen pin changes and runs of
oscillator pulses. There are no expectations: the model and the RTL must
produce identical traces, and the model's coverage counters feed the gate.
"""
import random
import sys


def main():
    seed = int(sys.argv[1])
    out = sys.argv[2]
    ops = int(sys.argv[3]) if len(sys.argv) > 3 else 400
    r = random.Random(seed * 7919 + 17)
    L = []
    color = r.random() < 0.7
    base = 0x3D0 if color else 0x3B0

    def ow(p, v):
        L.append('OW %03x %02x' % (p, v & 0xFF))

    def crtc(i, v):
        ow(base + 4, i)
        ow(base + 5, v)

    def small_crtc():
        ht = r.randint(4, 24)
        hde = r.randint(0, ht)
        vt = r.randint(3, 30)
        vals = [ht, hde, r.randint(0, ht + 1) if r.random() < 0.8 else r.randint(0, 255),
                r.randint(0, 127),
                r.randint(0, ht + 1), r.randint(0, 255), vt,
                r.choice([0x00, 0x10, 0x00, 0x1E, 0x3F]) & 0x3E,
                r.randint(0, 3) if r.random() < 0.8 else r.randint(0, 31),
                r.randint(0, 7), r.randint(0, 31), r.randint(0, 0x7F),
                r.randint(0, 3), r.randint(0, 255), r.randint(0, 3), r.randint(0, 255),
                r.randint(0, vt + 1), r.choice([0x10, 0x10, 0x00, 0x30, 0x1F, 0x05]) | r.randint(0, 15),
                r.randint(0, vt), r.randint(0, 40), r.randint(0, 9),
                r.randint(0, vt + 1) if r.random() < 0.8 else r.randint(0, 255),
                r.randint(0, 31), r.randint(0, 255) | 0x80, r.randint(0, vt + 2)]
        for i, v in enumerate(vals):
            crtc(i, v)

    # power-on setup
    misc = (0x03 if color else 0x02) | (r.randint(0, 1) << 2) | (r.randint(0, 1) << 5) \
        | (r.randint(0, 3) << 6)
    ow(0x3C4, 0)
    ow(0x3C5, 1)
    ow(0x3C2, misc)
    for i in range(1, 5):
        ow(0x3C4, i)
        ow(0x3C5, r.randint(0, 255))
    small_crtc()
    ow(0x3CC, 0)
    ow(0x3CA, 1)
    for i in range(9):
        ow(0x3CE, i)
        v = r.randint(0, 255)
        if i == 6 and r.random() < 0.5:
            v &= 0xFE                         # alphanumeric fetch
        ow(0x3CF, v)
    L.append('OR %03x' % (base + 0xA))
    for i in range(0x14):
        ow(0x3C0, i)
        v = r.randint(0, 255)
        if i == 0x10 and r.random() < 0.5:
            v &= 0xFE                         # alphanumeric attribute mode
        if i == 0x13:
            v = seed % 16                     # every panning value over 16 seeds
        ow(0x3C0, v)
    ow(0x3C0, 0x20)
    ow(0x3C4, 0)
    ow(0x3C5, 3)

    ports_w = [0x3C0, 0x3C2, 0x3C4, 0x3C5, 0x3CA, 0x3CC, 0x3CE, 0x3CF,
               0x3B4, 0x3B5, 0x3BA, 0x3BB, 0x3BC, 0x3D4, 0x3D5, 0x3DA, 0x3DB, 0x3DC,
               0x3C1, 0x3C3, 0x3D0, 0x3D8, 0x3D9, 0x3B8, 0x2D4]
    ports_r = [0x3C2, 0x3BA, 0x3DA, 0x3B5, 0x3D5, 0x3B4, 0x3D4, 0x3C0, 0x3C1, 0x3C4,
               0x3C5, 0x3CE, 0x3CF, 0x3CA, 0x3CC, 0x3D8, 0x7DA, 0x0BC2, 0x2DA]
    for _ in range(ops):
        k = r.random()
        if k < 0.30:
            p = r.choice(ports_w)
            if r.random() < 0.15:
                p |= r.randint(1, 63) << 10           # A15-A10 aliases
            if p & 0x3FF in (0x3C5,) and r.random() < 0.5:
                ow(0x3C4, r.randint(0, 6))
            if (p & 0x3FF) in (0x3B5, 0x3D5) and r.random() < 0.7:
                i = r.randint(0, 0x1A)
                ow(p - 1, i)
                if i in (0, 6):
                    v = r.randint(3, 30)
                elif i == 7:
                    v = r.randint(0, 255) & 0xFE
                else:
                    v = r.randint(0, 255)
                ow(p, v)
                continue
            if (p & 0x3FF) == 0x3CF and r.random() < 0.7:
                ow(0x3CE, r.randint(0, 10))
            v = r.randint(0, 255)
            if (p & 0x3FF) == 0x3C2:
                if r.random() < 0.8:
                    v = (v & 0xF3) | (r.choice([0, 1]) << 2)
                if r.random() < 0.8:
                    v |= 0x02
            if (p & 0x3FF) == 0x3C5 and r.random() < 0.3:
                ow(0x3C4, 0)
                v = r.choice([3, 3, 3, 1, 2, 0])
            if p == 0x3C0 and r.random() < 0.3:
                L.append('OR %03x' % r.choice([0x3BA, 0x3DA]))
            if r.random() < 0.05:
                L.append('OWN %03x %02x' % (p, v))
            else:
                ow(p, v)
        elif k < 0.40:
            p = r.choice(ports_r)
            L.append(('ORN %03x' if r.random() < 0.05 else 'OR %03x') % p)
        elif k < 0.58:
            a = r.choice([0xA0000, 0xA8000, 0xB0000, 0xB8000, 0xBC000]) + r.randint(0, 0x3FFF)
            if r.random() < 0.1:
                a = r.randint(0x9F000, 0xC4100)
            L.append('MW %05x %02x' % (a, r.randint(0, 255)))
        elif k < 0.70:
            a = r.choice([0xA0000, 0xA8000, 0xB0000, 0xB8000, 0xBC000, 0xC0000]) + r.randint(0, 0x3FFF)
            L.append('MR %05x' % a)
        elif k < 0.90:
            L.append('T %d' % r.choice([r.randint(1, 40), r.randint(40, 800), r.randint(800, 4000)]))
        elif k < 0.92:
            small_crtc()
        elif k < 0.935:
            L.append('DACK 0')
            L.append(r.choice(['MR %05x' % (0xA0000 + r.randint(0, 0xFFFF)), 'MW b8000 55',
                               'MR c0010']))
            L.append('DACK 1')
        elif k < 0.945:
            L.append('RST 1')
            L.append('RST 0')
            ow(0x3C2, misc)
        elif k < 0.96:
            L.append(r.choice(['LP 0', 'LP 1', 'LPSW 0', 'LPSW 1']))
        elif k < 0.97:
            L.append('SW %x' % r.randint(0, 15))
            L.append('FEAT %x' % r.randint(0, 3))
        elif k < 0.975:
            L.append('P1 %d' % r.randint(0, 1))
        elif k < 0.98:
            L.append('P3 0')
            ow(0x2C2, r.randint(0, 255))
            L.append('OR 2c2')
            L.append('P3 1')
        elif k < 0.983:
            # occasionally a long frame (vertical total bits 5-8), then back
            crtc(6, r.randint(0, 255))
            crtc(7, r.randint(0, 255))
            L.append('T %d' % r.randint(1, 500))
            small_crtc()
        elif k < 0.986:
            # 512-character sets: two maps, alpha + extended memory, text
            ow(0x3C4, 3)
            ow(0x3C5, r.randint(0, 15))
            ow(0x3C4, 4)
            ow(0x3C5, r.choice([3, 7]))
            m = r.randint(0, 3)
            ow(0x3CE, 6)
            ow(0x3CF, (m << 2) | (r.randint(0, 1) << 1))
            ow(0x3C4, 2)
            ow(0x3C5, 0x0F)
            b = [0xA0000, 0xA0000, 0xB0000, 0xB8000][m]
            for i in range(16):
                L.append('MW %05x %02x' % (b + i, r.choice([0xFF, 0x08, 0x41])))
            L.append('T %d' % r.randint(100, 2000))
        elif k < 0.99:
            # vertical interrupt programming
            crtc(0x11, r.choice([0x15, 0x05, 0x35, 0x10, 0x00]) | r.randint(0, 15))
        elif k < 0.995:
            L.append('OR %03x' % (base + 0xA))
            ow(0x3C0, 0x13)
            ow(0x3C0, r.randint(0, 15))
            ow(0x3C0, 0x20)
        else:
            L.append('DUMPR')
    L.append('DUMPR')
    for p in range(4):
        L.append('DUMPM %d 0000 10000' % p)    # every byte of every plane
    with open(out, 'w') as f:
        f.write('# random seed %d\n' % seed + '\n'.join(L) + '\n')


if __name__ == '__main__':
    main()
