#!/usr/bin/env python3
"""External Am29337 functional interpreter; no RTL parsing or DUT logic.

Sources: 1988 data book Tables 1/2 and the signed/unsigned comparison
description (page images inspected). The model steps through every
drive; outputs are checked before each edge.
"""
import itertools
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v

class Model:
    def __init__(self):
        self.l = 0
        self.u = 0

    def step(self, d, enl_n, enu_n, signed, cil, ciu, edge):
        lt_l = (s16(d) < s16(self.l)) if signed else (d < self.l)
        le_l = (s16(d) <= s16(self.l)) if signed else (d <= self.l)
        lt_u = (s16(d) < s16(self.u)) if signed else (d < self.u)
        le_u = (s16(d) <= s16(self.u)) if signed else (d <= self.u)
        col = le_l if cil else lt_l
        cou = le_u if ciu else lt_u
        oob = int(not (col and cou))
        if edge:
            if not enl_n:
                self.l = d
            if not enu_n:
                self.u = d
        return {'col': int(col), 'cou': int(cou), 'oob': oob}

state = 0x293371987

def rnd16():
    global state
    s = state
    s ^= (s << 13) & 0xFFFFFFFF
    s ^= s >> 17
    s ^= (s << 5) & 0xFFFFFFFF
    state = s
    return s & 0xFFFF

model = Model()
lines = []
count = 0
# Directed: region boundaries around an explicit window loaded through
# the D bus (the model steps through the same load edges).
for signed, (l, u) in itertools.product((0, 1),
                                        ((0x1000, 0x2000),
                                         (0xF000, 0x7000))):
    count += 1
    res = model.step(l, 0, 1, signed, 0, 0, 1)
    lines.append(' '.join(format(v, 'x') for v in
        [l, 0, 1, signed, 0, 0, 1, res['col'], res['cou'], res['oob']]))
    count += 1
    res = model.step(u, 1, 0, signed, 0, 0, 1)
    lines.append(' '.join(format(v, 'x') for v in
        [u, 1, 0, signed, 0, 0, 1, res['col'], res['cou'], res['oob']]))
    for enl_n, enu_n, edge in itertools.product((0, 1), repeat=3):
        for d in (l, u, (l - 1) & 0xFFFF, (u + 1) & 0xFFFF, 0, 0xFFFF,
                  0x8000, 0x7FFF):
            for cil, ciu in ((0, 0), (0, 1), (1, 0), (1, 1)):
                count += 1
                res = model.step(d, enl_n, enu_n, signed, cil, ciu, edge)
                lines.append(' '.join(format(v, 'x') for v in
                    [d, enl_n, enu_n, signed, cil, ciu, edge,
                     res['col'], res['cou'], res['oob']]))
# Random: full space with interleaved limit reloads.
for _ in range(30000):
    d, enl_n, enu_n = rnd16(), rnd16() & 1, rnd16() & 1
    signed, cil, ciu = rnd16() & 1, rnd16() & 1, rnd16() & 1
    edge = rnd16() & 1
    count += 1
    res = model.step(d, enl_n, enu_n, signed, cil, ciu, edge)
    lines.append(' '.join(format(v, 'x') for v in
        [d, enl_n, enu_n, signed, cil, ciu, edge,
         res['col'], res['cou'], res['oob']]))

out_path = (ROOT / 'work' / 'sim' / 'vectors.txt').resolve()
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(''.join(line + '\n' for line in lines))
print(f'Am29337 functional oracle: {count} independent comparisons')
