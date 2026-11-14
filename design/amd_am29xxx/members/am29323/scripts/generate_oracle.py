#!/usr/bin/env python3
"""External Am29323 functional interpreter; no RTL parsing or DUT logic.

Sources: 1985 handbook pages 48-49 (Tables 1-3 and the X/Y/P data-format
figures, page images inspected) and the 1988 CMOS datasheet SHIFT AND
ACCUMULATE definition. The model steps through every drive the testbench
performs, including readback windows, keeping register history in
lockstep. Outputs are checked before each vector's clock edge (the
registered state plus the current command pins); the edge then updates
registers when the vector requests it.
"""
import itertools
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
M67 = (1 << 67) - 1

def wrap67(v):
    v &= M67
    return v - (1 << 67) if v >> 66 else v

def sext(v, w):
    v &= (1 << w) - 1
    return v - (1 << w) if v >> (w - 1) else v

def qbits(src67):
    u = src67 & M67
    return [(u >> k) & 1 for k in range(67)]

def slices(rnd, psrc):
    """Word slices per the FA figure and Tables 2/3 from the slice source
    (accumulator register, or the raw array product with FTP)."""
    q = qbits(psrc)
    lo1 = sum(q[k] << k for k in range(32))                # Pi
    lo0 = sum(q[k] << (k + 1) for k in range(31))          # Pi-1, LSB zero
    hi1 = sum(q[32 + k] << k for k in range(32))           # Pi+32
    hi0 = sum(q[31 + k] << k for k in range(32))           # Pi+31
    if rnd:
        hi1 = (hi1 + q[31]) & 0xFFFFFFFF                   # round MS word
        hi0 = (hi0 + q[30]) & 0xFFFFFFFF
    return {'lo1': lo1, 'lo0': lo0, 'hi1': hi1, 'hi0': hi0}

def parity4(w):
    r = 0
    for b in range(4):
        r |= (bin((w >> (8 * b)) & 0xFF).count('1') & 1) << b
    return r

class Model:
    def __init__(self):
        self.xa = self.xb = self.ya = self.yb = self.t = 0
        self.acc = 0
        self.i = 0

    def step(self, v):
        xm = v['x'] if v['ftx'] else (self.xa if v['xsel'] else self.xb)
        ym = v['y'] if v['fty'] else (self.ya if v['ysel'] else self.yb)
        sa = sext(xm, 32) if v['tcx'] else xm
        sb = sext(ym, 32) if v['tcy'] else ym
        prod64 = (sa * sb) & 0xFFFFFFFFFFFFFFFF
        prod67 = sext(prod64, 64)
        cmd = v['cmd'] if v['fti'] else self.i
        acc1 = (cmd >> 6) & 1
        acc0 = (cmd >> 5) & 1
        rnd  = (cmd >> 4) & 1
        tsel = (cmd >> 3) & 1
        fa   = (cmd >> 2) & 1
        ps1  = (cmd >> 1) & 1
        ps0  = cmd & 1
        acc_shifted = sext((self.acc & M67) >> 32, 35)
        if acc1 == 0 and acc0 == 0:
            acc_n = prod67                                   # PASS
        elif acc1 == 0 and acc0 == 1:
            acc_n = wrap67(self.acc + prod67)                # ACCUMULATE
        elif acc1 == 1 and acc0 == 0:
            acc_n = self.acc                                 # INVALID: hold
        else:
            acc_n = wrap67(acc_shifted + prod67)             # SHIFT AND ACC
        psrc = prod67 if v['ftp'] else self.acc
        sl = slices(rnd, psrc)
        t_in = (sl['hi1'] if fa else sl['hi0']) if tsel else \
               (sl['lo1'] if fa else sl['lo0'])
        disable = ps1 == 1 and ps0 == 1
        if ps1 == 0 and ps0 == 0:
            p_mux = self.t
        elif ps1 == 0 and ps0 == 1:
            p_mux = sl['lo1'] if fa else sl['lo0']
        elif ps1 == 1 and ps0 == 0:
            p_mux = sl['hi1'] if fa else sl['hi0']
        else:
            p_mux = 0
        p_oe = (not v['oe_n']) and not disable and not v['slave']
        pp = parity4(p_mux)
        perr = ((v['px'] ^ parity4(v['x'])) != 0) or \
               ((v['py'] ^ parity4(v['y'])) != 0)
        cmp_err = ((p_oe and p_mux != v['p']) or
                   (p_oe and pp != v['pp']) or
                   ((not v['slave']) and int(perr) != v['parerr']))
        out = {'p': p_mux, 'p_oe': int(p_oe), 'pp': pp,
               'parerr': int(perr), 'parerr_oe': int(not v['slave']),
               'harderr': int(cmp_err)}
        if v['edge']:
            if not v['enxa_n']:
                self.xa = v['x']
            if not v['enxb_n']:
                self.xb = v['x']
            if not v['enya_n']:
                self.ya = v['y']
            if not v['enyb_n']:
                self.yb = v['y']
            if not v['enp_n']:
                self.acc = acc_n
            if not v['ent_n']:
                self.t = t_in
            if not v['eni_n']:
                self.i = v['cmd']
        return out

state = 0x293231985

def rnd32():
    global state
    s = state
    s ^= (s << 13) & 0xFFFFFFFF
    s ^= s >> 17
    s ^= (s << 5) & 0xFFFFFFFF
    state = s
    return s

model = Model()
lines = []
count = 0
FIELDS = ('x', 'y', 'px', 'py', 'p', 'pp', 'parerr', 'tcx', 'tcy', 'cmd',
          'enxa_n', 'enxb_n', 'enya_n', 'enyb_n', 'enp_n', 'eni_n', 'ent_n',
          'ftx', 'fty', 'fti', 'ftp', 'xsel', 'ysel', 'oe_n', 'slave',
          'edge')

def emit(**kw):
    global count
    count += 1
    base = dict(x=0, y=0, px=0, py=0, p=0, pp=0, parerr=0, tcx=0, tcy=0,
                cmd=0, enxa_n=1, enxb_n=1, enya_n=1, enyb_n=1, enp_n=1,
                eni_n=1, ent_n=1, ftx=0, fty=0, fti=0, ftp=0, xsel=0,
                ysel=0, oe_n=0, slave=0, edge=0)
    base.update(kw)
    res = model.step(base)
    fields = [base[k] for k in FIELDS]
    lines.append(' '.join(format(f, 'x') for f in fields + [
        res['p'], res['p_oe'], res['pp'], res['parerr'],
        res['parerr_oe'], res['harderr']]))

def readback():
    """Slice readback drives: no clock edge, enables inactive, FTI direct
    commands; the model steps through them for latch lockstep."""
    for ps in (0b00, 0b01, 0b10):
        for fa in (0, 1):
            emit(cmd=ps | (fa << 2), fti=1)

def even_parity_bytes(w):
    return parity4(w)

DIRECT_PRODUCTS = [(0x12345678, 0x9ABCDEF0), (0x80000000, 0x80000000),
                   (0x7FFFFFFF, 0x7FFFFFFF), (0xDEADBEEF, 0x00000001),
                   (0xFFFFFFFF, 0xFFFFFFFF), (0x55555555, 0xAAAAAAAA)]
for (xv, yv), (tcx, tcy), (acc1, acc0) in itertools.product(
        DIRECT_PRODUCTS[:3], ((0, 0), (0, 1), (1, 0), (1, 1)),
        ((0, 0), (0, 1), (1, 0))):
    px = even_parity_bytes(xv)
    py = even_parity_bytes(yv)
    emit(x=xv, y=yv, px=px, py=py, enxa_n=0, enya_n=0, edge=1)
    emit(cmd=(acc1 << 6) | (acc0 << 5), tcx=tcx, tcy=tcy, enp_n=0,
         ftx=1, fty=1, edge=1)
    for rnd in (0, 1):
        for ps in (0b00, 0b01, 0b10, 0b11):
            for fa in (0, 1):
                emit(cmd=(acc1 << 6) | (acc0 << 5) | (rnd << 4) |
                     (fa << 2) | ps, fti=1, tcx=tcx, tcy=tcy,
                     oe_n=1 if ps == 0b11 else 0)
    for tsel in (0, 1):
        for fa in (0, 1):
            emit(cmd=(tsel << 3) | (fa << 2), fti=1, ent_n=0, edge=1)
            emit(cmd=0, fti=1)

# Mixed modes and accumulate / shift-and-accumulate flows, with slice
# readback after every operation to isolate any divergence.
for (xv, yv) in DIRECT_PRODUCTS[3:]:
    for (tcx, tcy) in ((0, 0), (0, 1), (1, 0), (1, 1)):
        emit(x=xv, y=yv, enxa_n=0, enya_n=0, edge=1)
        emit(tcx=tcx, tcy=tcy, enp_n=0, ftx=1, fty=1, edge=1)
        readback()
        emit(tcx=tcx, tcy=tcy, cmd=1 << 5, enp_n=0, ftx=1, fty=1, edge=1)
        readback()
        emit(tcx=tcx, tcy=tcy, cmd=3 << 5, enp_n=0, ftx=1, fty=1, edge=1)
        readback()

# Multiprecision 64x64 in the datasheet's seven cycles: XA*YA low word,
# then XB*YA, XA*YB, XB*YB with SHIFT AND ACCUMULATE.
emit(x=0x11112222, y=0x33334444, enxa_n=0, enya_n=0, edge=1)
emit(x=0x55556666, y=0x77778888, enxb_n=0, enyb_n=0, edge=1)
emit(cmd=0, ftx=1, fty=1, enp_n=0, edge=1)                  # XA*YA PASS
emit(xsel=0, ysel=1, cmd=2 << 5, enp_n=0, edge=1)           # XB*YA shift+acc
emit(xsel=1, ysel=0, cmd=1 << 5, enp_n=0, edge=1)           # XA*YB acc
emit(xsel=1, ysel=1, cmd=1 << 5, enp_n=0, edge=1)           # XB*YB acc
readback()

# Random drives over the full input space with interleaved readbacks.
for _ in range(6000):
    emit(x=rnd32() & 0xFFFFFFFF, y=rnd32() & 0xFFFFFFFF,
         px=rnd32() & 0xF, py=rnd32() & 0xF,
         p=rnd32() & 0xFFFFFFFF, pp=rnd32() & 0xF, parerr=rnd32() & 1,
         tcx=rnd32() & 1, tcy=rnd32() & 1, cmd=rnd32() & 0x7F,
         enxa_n=rnd32() & 1, enxb_n=rnd32() & 1, enya_n=rnd32() & 1,
         enyb_n=rnd32() & 1, enp_n=rnd32() & 1, eni_n=rnd32() & 1,
         ent_n=rnd32() & 1, ftx=rnd32() & 1, fty=rnd32() & 1,
         fti=rnd32() & 1, ftp=rnd32() & 1, xsel=rnd32() & 1,
         ysel=rnd32() & 1, oe_n=rnd32() & 1, slave=rnd32() & 1,
         edge=rnd32() & 1)
    if count % 8 == 0:
        emit(fti=1, oe_n=0)

out_path = (ROOT / 'work' / 'sim' / 'vectors.txt').resolve()
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(''.join(line + '\n' for line in lines))
print(f'Am29323 functional oracle: {count} independent drives')
