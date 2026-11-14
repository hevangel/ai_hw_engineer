#!/usr/bin/env python3
"""External Am29334 functional interpreter; no RTL parsing or DUT logic.

Behavior source: 1988 data book pages 3-79 (functional description),
pin descriptions 3-79, Figure 2 read/write timing. The model keeps a
sparse per-byte RAM image and the two output latch values, and steps
through every drive the testbench performs - including the readback
windows - so expectations stay in lockstep with DUT latch history.
"""
import itertools
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class _Rng:
    """Deterministic xorshift32 stimulus."""
    def __init__(self, seed):
        self.s = (seed & 0xFFFFFFFF) or 0x293341986

    def randrange(self, n):
        s = self.s
        s ^= (s << 13) & 0xFFFFFFFF
        s ^= s >> 17
        s ^= (s << 5) & 0xFFFFFFFF
        self.s = s
        return s % n

rng = _Rng(0x293341986)

class Model:
    def __init__(self):
        self.cells = {}   # addr -> [low, high] with None for undefined byte
        self.ya = 0
        self.yb = 0

    def read(self, addr):
        c = self.cells.get(addr)
        if c is None or c[0] is None or c[1] is None:
            return None
        return (c[1] << 9) | c[0]

    def step(self, ara, awa, arb, awb, da, db, bits):
        lea = bits & 1
        leb = (bits >> 1) & 1
        oea_n = (bits >> 2) & 1
        oeb_n = (bits >> 3) & 1
        weac = (bits >> 4) & 1
        weal = (bits >> 5) & 1
        weah = (bits >> 6) & 1
        webc = (bits >> 7) & 1
        webl = (bits >> 8) & 1
        webh = (bits >> 9) & 1
        rama = ara if weac else awa
        ramb = arb if webc else awb
        # Asynchronous writes; a same-cell-and-byte collision (both sides
        # in one window) resolves with the A side winning that cell
        # (model choice, see spec ledger). Different cells or bytes write
        # concurrently.
        same_cell = (not weac) and (not webc) and (awa == awb)
        if not weac:
            c = self.cells.setdefault(awa, [None, None])
            if not weal:
                c[0] = da & 0x1FF
            if not weah:
                c[1] = (da >> 9) & 0x1FF
        if not webc:
            c = self.cells.setdefault(awb, [None, None])
            if not webl and not (same_cell and not weal):
                c[0] = db & 0x1FF
            if not webh and not (same_cell and not weah):
                c[1] = (db >> 9) & 0x1FF
        if lea:
            v = self.read(rama)
            if v is not None:
                self.ya = v
        if leb:
            v = self.read(ramb)
            if v is not None:
                self.yb = v
        return {'ya': self.ya, 'yb': self.yb,
                'ya_ok': self.read(rama) is not None,
                'yb_ok': self.read(ramb) is not None}

# Readback drive: read window open on the observed side, both latches
# transparent (mirrors the driver's read_cell pin pattern).
def read_bits(bside):
    return 1 | (1 << 1) | ((0 if bside else 1) << 2) | ((1 if bside else 0) << 3) | \
           (1 << 4) | (1 << 7)

lines = []
count = 0
model = Model()

def emit(ara, awa, arb, awb, da, db, bits):
    global count
    count += 1
    res = model.step(ara, awa, arb, awb, da, db, bits)
    valid = (1 if res['ya_ok'] else 0) | (2 if res['yb_ok'] else 0)
    lines.append(' '.join(format(v, 'x') for v in
        [ara, awa, arb, awb, da, db, bits, res['ya'], res['yb'], valid]))

def emit_read(cell, bside):
    bits = read_bits(bside)
    emit(cell, 0, cell, 0, 0, 0, bits)

# Model's prewritten landscape; the driver writes the same cells first.
for i in range(64):
    model.cells[i] = [0x100 + i, 0x0A0 + i]

# Systematic: byte-enable combinations across address corners and latch
# states, with readback windows folded into the stream.
addr_corners = [0, 1, 31, 32, 62, 63]
for awa, weac, weal, weah, lea, oea_n in itertools.product(
        addr_corners, (0, 1), (0, 1), (0, 1), (0, 1), (0, 1)):
    bits = lea | (1 << 1) | (oea_n << 2) | (0 << 3) | (weac << 4) | \
           (weal << 5) | (weah << 6)
    emit(rng.randrange(64), awa, rng.randrange(64), rng.randrange(64),
         rng.randrange(1 << 18), rng.randrange(1 << 18), bits)
    if count % 8 == 0:
        emit_read(awa, False)
# Cross-port simultaneous write and transparency cases.
for awa, awb, same in itertools.product(addr_corners[:3], addr_corners[:3], (0, 1)):
    awb_eff = awa if same else awb
    for weal, weah, webl, webh in itertools.product((0, 1), repeat=4):
        bits = 1 | (1 << 1) | (weal << 5) | (weah << 6) | \
               (webl << 8) | (webh << 9)
        emit(awa, awa, awb, awb_eff, rng.randrange(1 << 18),
             rng.randrange(1 << 18), bits)
    emit_read(awa, False)
    emit_read(awb_eff, True)
# Random full-space exploration with interleaved readbacks.
for _ in range(20000):
    emit(rng.randrange(64), rng.randrange(64), rng.randrange(64),
         rng.randrange(64), rng.randrange(1 << 18), rng.randrange(1 << 18),
         rng.randrange(1 << 10))
    if count % 4 == 0:
        cell = rng.randrange(64)
        emit_read(cell, rng.randrange(2))

# Driver init write sequence: cells 0..63 full-word via the A port. The
# model already holds this image; these drives keep the DUT in lockstep.
out_path = (ROOT / 'work' / 'sim' / 'vectors.txt').resolve()
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(''.join(line + '\n' for line in lines))
print(f'Am29334 functional oracle: {count} independent drive cases')
