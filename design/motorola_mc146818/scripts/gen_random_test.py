#!/usr/bin/env python3
"""Seeded random operation sequence for the MC146818 lockstep bench.

usage: gen_random_test.py SEED OUT.txt [OPS]

Intended for FAST_SHIFT 6 (one second = 512 ticks with the 32.768 kHz
base). The sequence mixes bus writes and reads of all 64 locations (with
values biased towards calendar edges, alarm don't-care codes, every
register bit and both data/hour modes), runs of ticks long enough to cross
many seconds, UIP polling followed by accesses inside the update window,
RESET and PS pin pulses and cycles with CE high. No expectations are
written: the RTL is compared with the model.
"""
import random
import sys


def bcd(x):
    return ((x // 10) << 4) | (x % 10)


def main():
    seed = int(sys.argv[1])
    out = sys.argv[2]
    nops = int(sys.argv[3]) if len(sys.argv) > 3 else 1500
    r = random.Random(seed)
    s = ['# random seed %d' % seed]
    binary = r.random() < 0.4
    h24 = r.random() < 0.5

    def enc(x):
        return x if binary else bcd(x)

    def regb_mode():
        return (0x04 if binary else 0) | (0x02 if h24 else 0) | (r.random() < 0.3)

    def near_edge():
        """Write a complete time a few seconds before a rollover."""
        y = r.randrange(100)
        kind = r.randrange(6)
        mon = 2 if kind == 0 else (12 if kind == 1 else r.randrange(1, 13))
        if kind == 0:
            date = r.choice([28, 29])
        else:
            date = {2: 28 + (y % 4 == 0), 4: 30, 6: 30, 9: 30, 11: 30}.get(mon, 31)
        if kind == 2:
            date = r.randrange(1, 28)
        if kind == 5 and r.random() < 0.5:
            mon, date = r.choice([(4, r.randrange(22, 31)), (10, r.randrange(23, 32))])
        hour = 23 if kind != 3 else r.choice([0, 1, 11, 12, 13])
        if r.random() < 0.3:
            hour = 1
        sec = r.randrange(55, 60)
        mnt = 59 if r.random() < 0.8 else r.randrange(60)
        if h24:
            hb = enc(hour)
        else:
            h = hour % 12
            hb = enc(12 if h == 0 else h) | (0x80 if hour >= 12 else 0)
        dow = r.randrange(1, 8) if r.random() < 0.7 else 1
        vals = {0: enc(sec), 2: enc(mnt), 4: hb, 6: dow, 7: enc(date),
                8: enc(mon), 9: enc(y)}
        mode = regb_mode()
        cmds = []
        if r.random() < 0.7:
            cmds.append('W 0B %02X' % (0x80 | mode))
        for a, v in vals.items():
            cmds.append('W %02X %02X' % (a, v))
        # alarm
        if r.random() < 0.6:
            for a, base in ((1, vals[0]), (3, vals[2]), (5, vals[4])):
                c = r.random()
                v = (r.randrange(0xC0, 0x100) if c < 0.4 else
                     (base + r.randrange(0, 4)) & 0xFF if c < 0.8 else r.randrange(256))
                cmds.append('W %02X %02X' % (a, v))
        cmds.append('W 0B %02X' % (mode | r.choice([0, 0x10, 0x20, 0x40, 0x70, 0x08])))
        return cmds

    def rega_val():
        c = r.random()
        dv = 2 if c < 0.85 else r.choice([0, 1, 3, 4, 5, 6, 7])
        return (dv << 4) | r.randrange(16)

    s += ['W 0A 70', 'W 0A %02X' % (0x20 | r.randrange(16))]
    s += near_edge()
    for _ in range(nops):
        c = r.random()
        if c < 0.08:
            s += near_edge()
        elif c < 0.13:
            s.append('W 0A %02X' % rega_val())
        elif c < 0.18:
            v = r.randrange(256)
            if r.random() < 0.7:
                v &= 0x7F
            s.append('W 0B %02X' % v)
        elif c < 0.30:
            s.append('R 0C')
        elif c < 0.34:
            s.append('R 0D')
        elif c < 0.38:
            s.append('R 0A')
        elif c < 0.47:
            s.append('R %02X' % r.randrange(64))
        elif c < 0.55:
            a = r.randrange(64)
            s.append('W %02X %02X' % (a, r.randrange(256)))
        elif c < 0.58:
            a = r.randrange(10)
            s.append('W %02X %02X' % (a, enc(r.randrange(60))))
        elif c < 0.61:
            # Find UIP, then access the window (writes may be lost in tUC).
            s.append('POLL 0A 80 80 600 3 soft')
            for _ in range(r.randrange(1, 4)):
                a = r.randrange(10)
                if r.random() < 0.5:
                    s.append('W %02X %02X' % (a, enc(r.randrange(24))))
                else:
                    s.append('R %02X' % a)
                if r.random() < 0.5:
                    s.append('T 1')
        elif c < 0.63:
            s.append('RST 0')
            if r.random() < 0.5:
                s.append('T %d' % r.randrange(1, 40))
            if r.random() < 0.3:
                s.append('R 0B')
            s.append('RST 1')
        elif c < 0.645:
            s.append('PS 0')
            if r.random() < 0.5:
                s.append('R 0D')
            s.append('PS 1')
        elif c < 0.66:
            s.append(r.choice(['WN %02X %02X' % (r.randrange(64), r.randrange(256)),
                               'RN %02X' % r.randrange(64)]))
        elif c < 0.67:
            # Address strobe then data strobe as separate commands.
            s.append('A %02X' % r.randrange(256))
            s.append(r.choice(['RD', 'WD %02X' % r.randrange(256)]))
        elif c < 0.68:
            s.append('DUMP')
        else:
            s.append('T %d' % r.choice([1, 2, 3, 7, 30, 100, r.randrange(1, 700)]))
    s.append('DUMP')
    with open(out, 'w') as f:
        f.write('\n'.join(s) + '\n')


if __name__ == '__main__':
    main()
