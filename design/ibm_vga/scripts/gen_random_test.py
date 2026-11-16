#!/usr/bin/env python3
"""Seeded random bench script for the IBM VGA lockstep bench.

usage: gen_random_test.py SEED OUT.txt [OPS]

The script starts from power-on, enables the card (46E8h/102h), programs a
random small display geometry (so that frames, retraces, line compares and
interrupts happen within the run) and then issues OPS random operations:
register writes to every port with random index and data (including
reserved indices, AEN-high cycles, A15-A10 aliases and the Protect bit),
I/O reads of decoded and undecoded ports, DAC address/data sequences in
both directions (including cross-direction accesses), processor memory
writes and reads in every window, chain 4, odd/even and the ROM, refresh
(DACK0) cycles, RESET DRV pulses, card disable/setup cycles, monitor-load
changes and runs of oscillator pulses. There are no expectations: the
model and the RTL must produce identical traces, and the model's coverage
counters feed the gate.
"""
import random
import sys


def main():
    seed = int(sys.argv[1])
    out = sys.argv[2]
    ops = int(sys.argv[3]) if len(sys.argv) > 3 else 400
    r = random.Random(seed * 7919 + 23)
    L = []
    color = r.random() < 0.7
    base = 0x3D0 if color else 0x3B0

    def ow(p, v):
        L.append('OW %03x %02x' % (p, v & 0xFF))

    def crtc(i, v):
        ow(base + 4, i)
        ow(base + 5, v)

    def enable():
        L.extend(['OW 46e8 16', 'OW 46e9 00', 'OW 102 01', 'OW 103 00', 'OW 46e8 0e',
                  'OW 46e9 00'])

    def small_crtc():
        crtc(0x11, r.randint(0, 0x7F))                   # Protect off
        ht = r.randint(1, 20)
        hde = r.randint(0, ht + 3)
        vt = r.randint(3, 30)
        vals = [ht, hde, r.randint(0, ht + 4) if r.random() < 0.8 else r.randint(0, 255),
                r.randint(0, 255),
                r.randint(0, ht + 4), r.randint(0, 255), vt,
                r.choice([0x00, 0x10, 0x00, 0x1E, 0x3E, 0x40, 0x80]) & 0xDE,
                r.randint(0, 3) if r.random() < 0.8 else r.randint(0, 127),
                r.choice([0, 1, 3, 7, 0x80, 0x81, 0x83, 0x87]) | (r.choice([0, 0, 0x40, 0x20])),
                r.randint(0, 63), r.randint(0, 0x7F),
                r.randint(0, 3), r.randint(0, 255), r.randint(0, 3), r.randint(0, 255),
                r.randint(0, vt + 1), r.choice([0x10, 0x10, 0x00, 0x30, 0x1F, 0x05]) | r.randint(0, 15),
                r.randint(0, vt), r.randint(0, 40), r.randint(0, 0x7F),
                r.randint(0, vt + 1) if r.random() < 0.8 else r.randint(0, 255),
                r.randint(0, 255), r.randint(0, 255) | (0x80 if r.random() < 0.9 else 0), r.randint(0, vt + 2)]
        for i, v in enumerate(vals):
            if i == 0x11:
                v &= 0x7F
            crtc(i, v)

    # power-on setup
    enable()
    misc = (0x03 if color else 0x02) | (r.randint(0, 1) << 2) | (r.randint(0, 1) << 5) \
        | (r.randint(0, 3) << 6)
    ow(0x3C4, 0)
    ow(0x3C5, 1)
    ow(0x3C2, misc)
    for i in range(1, 5):
        ow(0x3C4, i)
        ow(0x3C5, r.randint(0, 255))
    small_crtc()
    for i in range(9):
        ow(0x3CE, i)
        v = r.randint(0, 255)
        if i == 6 and r.random() < 0.5:
            v &= 0xFE
        ow(0x3CF, v)
    L.append('OR %03x' % (base + 0xA))
    for i in range(0x15):
        ow(0x3C0, i)
        v = r.randint(0, 255)
        if i == 0x10 and r.random() < 0.5:
            v &= 0xFE
        if i == 0x13:
            v = seed % 16
        ow(0x3C0, v)
    ow(0x3C0, 0x20)
    ow(0x3C6, r.choice([0xFF, 0xFF, 0x0F, r.randint(0, 255)]))
    ow(0x3C8, 0)
    for i in range(r.choice([16, 48, 256])):
        for k in range(3):
            ow(0x3C9, r.randint(0, 255))
    ow(0x3C4, 0)
    ow(0x3C5, 3)

    ports_w = [0x3C0, 0x3C1, 0x3C2, 0x3C3, 0x3C4, 0x3C5, 0x3C6, 0x3C7, 0x3C8, 0x3C9, 0x3CA,
               0x3CC, 0x3CE, 0x3CF, 0x3B4, 0x3B5, 0x3BA, 0x3D4, 0x3D5, 0x3DA, 0x3DB, 0x3D8,
               0x3B8, 0x2D4]
    ports_r = [0x3C0, 0x3C1, 0x3C2, 0x3C3, 0x3C4, 0x3C5, 0x3C6, 0x3C7, 0x3C8, 0x3C9, 0x3CA,
               0x3CC, 0x3CE, 0x3CF, 0x3BA, 0x3DA, 0x3B5, 0x3D5, 0x3B4, 0x3D4, 0x3D8, 0x7DA,
               0x0BC2, 0x46E8, 0x102, 0x2DA]
    for _ in range(ops):
        k = r.random()
        if k < 0.28:
            p = r.choice(ports_w)
            if r.random() < 0.12:
                p |= r.randint(1, 63) << 10
            q = p & 0x3FF
            if q == 0x3C5 and r.random() < 0.5:
                ow(0x3C4, r.randint(0, 7))
            if q in (0x3B5, 0x3D5) and r.random() < 0.7:
                i = r.randint(0, 0x1F)
                ow(p - 1, i)
                if i in (0, 6):
                    v = r.randint(1, 30)
                elif i == 7:
                    v = r.randint(0, 255) & 0xDE
                elif i == 0x11:
                    v = r.randint(0, 255) if r.random() < 0.3 else r.randint(0, 0x7F)
                else:
                    v = r.randint(0, 255)
                ow(p, v)
                continue
            if q == 0x3CF and r.random() < 0.7:
                ow(0x3CE, r.randint(0, 10))
            v = r.randint(0, 255)
            if q == 0x3C2:
                if r.random() < 0.8:
                    v = (v & 0xF3) | (r.choice([0, 1]) << 2)
                if r.random() < 0.8:
                    v |= 0x02
            if q == 0x3C5 and r.random() < 0.3:
                ow(0x3C4, 0)
                v = r.choice([3, 3, 3, 1, 2, 0])
            if p == 0x3C0 and r.random() < 0.3:
                L.append('OR %03x' % r.choice([0x3BA, 0x3DA]))
            if r.random() < 0.05:
                L.append('OWN %03x %02x' % (p, v))
            else:
                ow(p, v)
        elif k < 0.38:
            p = r.choice(ports_r)
            L.append(('ORN %03x' if r.random() < 0.05 else 'OR %03x') % p)
        elif k < 0.43:
            # DAC sequences, including cross-direction accesses (V20)
            ow(r.choice([0x3C7, 0x3C8]), r.randint(0, 255))
            for _ in range(r.randint(1, 7)):
                if r.random() < 0.5:
                    L.append('OR 3c9')
                else:
                    ow(0x3C9, r.randint(0, 255))
            L.append('OR 3c7')
            L.append('OR 3c8')
        elif k < 0.58:
            a = r.choice([0xA0000, 0xA8000, 0xB0000, 0xB8000, 0xBC000]) + r.randint(0, 0x3FFF)
            if r.random() < 0.1:
                a = r.randint(0x9F000, 0xC8100)
            L.append('MW %05x %02x' % (a, r.randint(0, 255)))
        elif k < 0.68:
            a = r.choice([0xA0000, 0xA8000, 0xB0000, 0xB8000, 0xBC000, 0xC0000, 0xC6000]) + \
                r.randint(0, 0x3FFF)
            L.append('MR %05x' % a)
        elif k < 0.86:
            L.append('T %d' % r.choice([r.randint(1, 40), r.randint(40, 800), r.randint(800, 4000)]))
        elif k < 0.88:
            small_crtc()
        elif k < 0.895:
            L.append('DACK 0')
            L.append(r.choice(['MR %05x' % (0xA0000 + r.randint(0, 0xFFFF)), 'MW b8000 55',
                               'MR c0010']))
            L.append('DACK 1')
        elif k < 0.905:
            L.append('RST 1')
            L.append('RST 0')
            enable()
            ow(0x3C2, misc)
        elif k < 0.915:
            # card disable / setup cycles (V4)
            seqs = [['OW 46e8 00', 'OR 3c2', 'MW a0000 77', 'OW 3c2 00', 'OW 46e8 0e'],
                    ['OW 46e8 16', 'OR 102', 'OW 102 00', 'OR 3c2', 'OW 102 01', 'OR 3c9',
                     'OW 46e8 0e'],
                    ['OW 46e8 1e', 'OR 3c8', 'OR 3c4', 'OW 46e8 0e'],
                    ['OW 46e8 %02x' % (r.randint(0, 255) | 0x08), 'OR 3cc', 'OR 3c6', 'OW 46e8 0e']]
            L.extend(r.choice(seqs))
        elif k < 0.925:
            L.append('LOAD %x' % r.choice([0, 2, 7, r.randint(0, 7)]))
            L.append('OR 3c2')
        elif k < 0.935:
            crtc(6, r.randint(0, 255))
            crtc(7, r.randint(0, 255))
            L.append('T %d' % r.randint(1, 500))
            small_crtc()
        elif k < 0.945:
            # 512-character sets: two maps, text, extended memory
            ow(0x3C4, 3)
            ow(0x3C5, r.randint(0, 63))
            ow(0x3C4, 4)
            ow(0x3C5, r.choice([0x02, 0x06, 0x0A]))
            m = r.randint(0, 3)
            ow(0x3CE, 6)
            ow(0x3CF, (m << 2) | (r.randint(0, 1) << 1))
            ow(0x3C4, 2)
            ow(0x3C5, 0x0F)
            b = [0xA0000, 0xA0000, 0xB0000, 0xB8000][m]
            for i in range(16):
                L.append('MW %05x %02x' % (b + i, r.choice([0xFF, 0x08, 0x41])))
            L.append('T %d' % r.randint(100, 2000))
        elif k < 0.96:
            # chain 4 / 256 colours / PEL width
            ow(0x3C4, 4)
            ow(0x3C5, 0x0E)
            ow(0x3CE, 5)
            ow(0x3CF, 0x40 | r.randint(0, 3))
            L.append('OR %03x' % (base + 0xA))
            ow(0x3C0, 0x10)
            ow(0x3C0, r.choice([0x41, 0x41, 0xC1, 0x61]))
            ow(0x3C0, 0x20)
            for i in range(8):
                L.append('MW %05x %02x' % (0xA0000 + r.randint(0, 0xFFFF), r.randint(0, 255)))
            L.append('T %d' % r.randint(100, 2000))
        elif k < 0.975:
            crtc(0x11, r.choice([0x15, 0x05, 0x35, 0x10, 0x00, 0x95]) | r.randint(0, 15))
        elif k < 0.99:
            L.append('OR %03x' % (base + 0xA))
            ow(0x3C0, r.choice([0x13, 0x14, 0x30, 0x33, 0x34]))
            ow(0x3C0, r.randint(0, 15))
            ow(0x3C0, 0x20)
        else:
            L.append('DUMPR')
    L.append('DUMPR')
    L.append('DUMPDAC')
    for p in range(4):
        L.append('DUMPM %d 0000 10000' % p)
    with open(out, 'w') as f:
        f.write('# random seed %d\n' % seed + '\n'.join(L) + '\n')


if __name__ == '__main__':
    main()
