#!/usr/bin/env python3
"""External Am29338 functional interpreter; no RTL parsing or DUT logic.

Sources: 1988 data book pages 3-122..3-127 (pin descriptions,
functional description, Figures 1-7, Tables 1-4, page images
inspected). Byte-stream model: 128-byte ring with parity, BSW input
reorder, LSB-first disassembly, pointer window output. The model steps
through every drive the testbench performs; outputs are checked before
each clock event.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def parity(b):
    return bin(b & 0xFF).count('1') & 1

state = 0x293381988

def rnd32():
    global state
    s = state
    s ^= (s << 13) & 0xFFFFFFFF
    s ^= s >> 17
    s ^= (s << 5) & 0xFFFFFFFF
    state = s
    return s & 0xFFFFFFFF

class Model:
    def __init__(self):
        self.mem = [None] * 128          # (parity, byte) or None
        self.q_ptr = 0
        self.d_ptr = 0
        self.q_cnt = 0
        self.d_cnt = 0
        self.prev_reset_n = 1

    def bsw_map(self, bsw):
        m = [0, 1, 2, 3]
        if bsw == 1:
            m = [1, 0, 3, 2]
        elif bsw == 2:
            m = [2, 3, 0, 1]
        elif bsw == 3:
            m = [3, 2, 1, 0]
        return m

    def bsw_bytes(self, d, bsw):
        orig = [(d >> (8 * k)) & 0xFF for k in range(4)]
        m = self.bsw_map(bsw)
        return [orig[m[k]] for k in range(4)]

    def count(self):
        c = self.q_cnt - self.d_cnt
        return 0 if c < 0 else (128 if c > 128 else c)

    def nq(self, bq):
        return 4 if bq == 0 else (2 * (bq >> 1) + (bq & 1))

    def ndq(self, bdq):
        return 16 if bdq == 0 else bdq

    def outputs(self, v):
        n_q = self.nq(v['bq'])
        n_dq = self.ndq(v['bdq'])
        m = self.bsw_map(v['bsw'])
        orig = [(v['d'] >> (8 * k)) & 0xFF for k in range(4)]
        ib = self.bsw_bytes(v['d'], v['bsw'])
        pderr = 0
        for k in range(n_q):
            if (v['pd'] >> m[k]) & 1 != parity(orig[m[k]]):
                pderr = 1
        cnt = self.count()
        yb = [self.mem[(self.d_ptr + k) & 127] for k in range(4)]
        y_oe = 1 - v['oe_n']
        py = 0
        pyerr = 0
        y_defined = all(x is not None for x in yb)
        if y_defined:
            y = sum(yb[k][1] << (8 * k) for k in range(4))
            for k in range(4):
                py |= yb[k][0] << k
                if yb[k][0] != parity(yb[k][1]):
                    pyerr = 1
        else:
            y = 0
        pyerr &= y_oe
        return {'y': y, 'y_oe': y_oe, 'py': py if y_defined else 0,
                'pyerr': pyerr, 'pderr': pderr, 'cnt': cnt & 0x7F,
                'full': int(cnt == 128), 'a_full': int(cnt > 124),
                'empty': int(cnt == 0), 'a_empty': int(cnt < 4),
                'y_defined': y_defined}

    def step(self, v):
        # RESET is asynchronous: the reset values load on the 1->0
        # transition and are re-assigned at each clock edge while RESET
        # stays low (POS changes between edges therefore hold). RXMIT is
        # sampled at DQCLK edges (synchronous assertion, documented
        # model choice); the rewind dominates the dequeue advance. All
        # clock-edge effects apply after the pre-edge outputs.
        pos_base = 32 * v['pos']
        if not v['reset_n'] and self.prev_reset_n:
            self.q_ptr = 0
            self.d_ptr = pos_base
            self.q_cnt = self.d_cnt = 0
        self.prev_reset_n = v['reset_n']
        out = self.outputs(v)
        if v['reset_n']:
            if not v['qen_n'] and v['qclk_edge']:
                n_q = self.nq(v['bq'])
                acc = min(n_q, 128 - self.count())
                ib = self.bsw_bytes(v['d'], v['bsw'])
                m = self.bsw_map(v['bsw'])
                for k in range(acc):
                    self.mem[(self.q_ptr + k) & 127] = \
                        ((v['pd'] >> m[k]) & 1, ib[k])
                self.q_ptr = (self.q_ptr + acc) & 127
                self.q_cnt = min(128, self.q_cnt + acc)
            if v['dqclk_edge']:
                if not v['rxmit_n']:
                    self.d_ptr = pos_base
                    self.d_cnt = pos_base
                elif not v['dqen_n']:
                    n_dq = self.ndq(v['bdq'])
                    self.d_ptr = (self.d_ptr + n_dq) & 127
                    self.d_cnt = min(128, self.d_cnt + n_dq)
        else:
            # RESET held low: the reset values re-assign at clock edges.
            if v['qclk_edge']:
                self.q_ptr = 0
                self.q_cnt = 0
            if v['dqclk_edge']:
                self.d_ptr = pos_base
                self.d_cnt = 0
        return out

model = Model()
lines = []
count = 0

def emit(**kw):
    global count
    count += 1
    base = dict(qclk_edge=0, dqclk_edge=0, qen_n=1, dqen_n=1, bq=0, bdq=0,
                bsw=0, d=0, pd=0, pos=0, reset_n=1, rxmit_n=1, oe_n=0)
    base.update(kw)
    res = model.step(base)
    fields = [base[k] for k in ('qclk_edge', 'dqclk_edge', 'qen_n',
                                'dqen_n', 'bq', 'bdq', 'bsw', 'd', 'pd',
                                'pos', 'reset_n', 'rxmit_n', 'oe_n')]
    lines.append(' '.join(format(f, 'x') for f in fields + [
        res['y'], res['y_oe'], res['py'], res['pyerr'], res['pderr'],
        res['cnt'], res['full'], res['a_full'], res['empty'],
        res['a_empty'], res['y_defined']]))

def rand_data():
    d = rnd32()
    pd = sum(parity((d >> (8 * k)) & 0xFF) << k for k in range(4))
    return d, pd

# Directed: Figures 6/7 sequences (queue 2 then 3; dequeue 1 then 2),
# BSW all four encodings, POS quadrants, RESET/RXMIT, fill to full.
d1, p1 = 0xAABBCCDD, sum(parity((0xAABBCCDD >> (8 * k)) & 0xFF) << k
                         for k in range(4))
d2, p2 = 0x11223344, sum(parity((0x11223344 >> (8 * k)) & 0xFF) << k
                         for k in range(4))
emit(reset_n=0)
emit(qclk_edge=1, qen_n=0, bq=1, d=d1, pd=p1)              # queue A
emit(dqclk_edge=1, dqen_n=0, bdq=1)                        # dequeue A
emit(qclk_edge=1, qen_n=0, bq=2, d=d2, pd=p2)              # queue C D
emit(dqclk_edge=1, dqen_n=0, bdq=2)                        # dequeue C D
# BSW sweep: queue one byte from each reordering.
for bsw in range(4):
    emit(reset_n=0)
    emit(qclk_edge=1, qen_n=0, bq=1, bsw=bsw, d=0xD3B7A296, pd=0)
    emit(dqclk_edge=1, dqen_n=0, bdq=1)
# Fill to full with four-byte words, checking FULL/A-FULL.
emit(reset_n=0)
for i in range(34):
    d, pd = rand_data()
    emit(qclk_edge=1, qen_n=0, bq=0, d=d, pd=pd)
# Drain everything.
for i in range(34):
    emit(dqclk_edge=1, dqen_n=0, bdq=0)
# RXMIT retransmit flow (Figure 5): queue 16 bytes, dequeue 8, RXMIT
# sampled at a DQCLK edge (synchronous assertion model).
emit(reset_n=0)
for i in range(4):
    d, pd = rand_data()
    emit(qclk_edge=1, qen_n=0, bq=0, d=d, pd=pd)
emit(dqclk_edge=1, dqen_n=0, bdq=0)                        # dequeue 4
emit(dqclk_edge=1, dqen_n=0, bdq=4)                        # dequeue 4 more
emit(dqclk_edge=1, dqen_n=0, rxmit_n=0)                    # retransmit rewind
for i in range(4):
    emit(dqclk_edge=1, dqen_n=0, bdq=0)                    # dequeue again
emit(reset_n=0)
# POS quadrant behavior under RESET and RXMIT.
for pos in range(4):
    emit(pos=pos, reset_n=0)
    emit(pos=pos, qclk_edge=1, qen_n=0, bq=0, d=0xDEADBEEF, pd=0)
    emit(pos=pos, dqclk_edge=1, dqen_n=0, rxmit_n=0)
# Simultaneous queue and dequeue at different pointers.
emit(reset_n=0)
for i in range(2):
    d, pd = rand_data()
    emit(qclk_edge=1, qen_n=0, bq=0, d=d, pd=pd)
for i in range(8):
    d, pd = rand_data()
    emit(qclk_edge=1, dqclk_edge=1, qen_n=0, dqen_n=0, bq=0, bdq=1,
         d=d, pd=pd)

# Random full-space drives with interleaved resets/retransmits.
for i in range(12000):
    d, pd = rand_data()
    emit(qclk_edge=rnd32() & 1, dqclk_edge=rnd32() & 1,
         qen_n=rnd32() & 1, dqen_n=rnd32() & 1, bq=rnd32() & 3,
         bdq=rnd32() & 0xF, bsw=rnd32() & 3, d=d, pd=pd,
         pos=rnd32() & 3, reset_n=1 if rnd32() % 32 else 0,
         rxmit_n=1 if rnd32() % 32 else 0, oe_n=rnd32() & 1)

out_path = (ROOT / 'work' / 'sim' / 'vectors.txt').resolve()
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(''.join(line + '\n' for line in lines))
print(f'Am29338 functional oracle: {count} independent drives')
