"""Generate ISS comparison vectors for the motorola_6800 full-ISA regression.

The independent oracle in this file is a MC6800 instruction-set simulator
written from the Motorola M6800 Programming Reference Manual M68PRM(D)
(Nov 1976) semantics only — the RTL is never consulted. It executes a
directed program that covers every documented opcode (197 codes) in every
addressing mode plus interrupt/WAI/SWI/NMI scenarios, and emits (into
<design>/work/sim):

  vectors.hex   one record per instruction boundary:
                pc a b ix sp cc (six 4-hex-digit words per line)
  mem.hex       the 64K memory image to load into the RTL testbench
  gold_mem.hex  the oracle's final memory (TB compares at the end)
  triggers.hex  external interrupt events keyed to program counters:
                pc action delay (action 0 = irq low, 1 = irq high,
                2 = nmi pulse; delay in clocks after the boundary)

Layout: program at $0100, zero-page data at $0040+, extended data at
$2000+, handlers at $F000 (IRQ) / $F100 (SWI) / $F200 (NMI), control
port at $E000, vectors at $FFF8-$FFFF.

Determinism: stimulus uses a small LCG (a fixed seed must always produce
the same vector set; this is a test-vector generator, not a security
control).
"""
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
DESIGN_ROOT = HERE.parent.resolve()
OUT_ROOT = (DESIGN_ROOT / 'work' / 'sim').resolve()
if DESIGN_ROOT not in OUT_ROOT.parents:
    raise RuntimeError('work dir escapes the design tree')

FC, FV, FZ, FN, FI, FH = 0x01, 0x02, 0x04, 0x08, 0x10, 0x20
CMASK = 0xC0  # condition-code bits 7-6 always read as 1

VEC_IRQ, VEC_SWI, VEC_NMI, VEC_RST = 0xFFF8, 0xFFFA, 0xFFFC, 0xFFFE
IO_PORT = 0xE000
MAIN = 0x0100
IRQ_H, SWI_H, NMI_H = 0xF000, 0xF100, 0xF200


class LCG:
    """Deterministic linear congruential generator (Numerical Recipes)."""

    def __init__(self, seed):
        self.s = seed & 0xFFFFFFFF

    def next(self):
        self.s = (self.s * 1664525 + 1013904223) & 0xFFFFFFFF
        return self.s

    def below(self, n):
        return self.next() % n

    def range(self, lo, hi):
        return lo + self.next() % (hi - lo)

    def choice(self, seq):
        return seq[self.next() % len(seq)]


# ---------------------------------------------------------------------------
# Independent instruction-set simulator (oracle)
# ---------------------------------------------------------------------------
def dec(d):
    """Decode one opcode byte -> (op_name, mode, acc).

    Modes: 0=inherent, 1=immediate, 2=direct, 3=extended, 4=indexed,
    5=relative. Mirrors the documented MC6800 opcode map (M68PRM Table
    3-1: 197 valid codes). Unassigned codes return 2-byte-NOP (or
    mode-length NOP) equivalents consistent with the design's documented
    assumption."""
    if d & 0x80:
        row = (d >> 4) & 0x7
        col = d & 0x0F
        mode = (1, 2, 4, 3)[row & 3]  # IMM, DIR, IND, EXT
        acc = not (d & 0x40)  # d[6]=0 selects ACCA (rows 8-B)
        colmap = {0: 'sub', 1: 'cmp', 2: 'sbc', 4: 'and', 5: 'bit',
                  6: 'lda', 8: 'eor', 9: 'adc', 10: 'ora', 11: 'add'}
        if col in colmap:
            return (colmap[col], mode, acc)
        if col == 7:
            if (row & 3) != 0:
                return ('sta', mode, acc)
            return ('nop', 1, acc)          # 87, C7: 2-byte no-op
        if col == 12:
            if row <= 3:
                return ('cpx', mode, acc)
            return ('nop', mode, acc)       # CC..FC
        if col == 13:
            if row == 0:
                return ('bsr', 5, acc)
            if row in (2, 3):
                return ('jsr', mode, acc)   # AD, BD
            return ('nop', 1 if row in (1, 4) else mode, acc)
        if col == 14:
            return ('lds' if row <= 3 else 'ldx', mode, acc)
        if col == 15:
            if row == 0:
                return ('nop', 1, acc)      # 8F, CF
            return ('sts' if row <= 3 else 'stx', mode, acc)
        return ('nop', mode, acc)           # col 3: unassigned
    table = {
        0x01: ('nop', 0), 0x06: ('tap', 0), 0x07: ('tpa', 0),
        0x08: ('inx', 0), 0x09: ('dex', 0), 0x0A: ('clv', 0),
        0x0B: ('sev', 0), 0x0C: ('clc', 0), 0x0D: ('sec', 0),
        0x0E: ('cli', 0), 0x0F: ('sei', 0),
        0x10: ('sba', 0), 0x11: ('cba', 0), 0x16: ('tab', 0),
        0x17: ('tba', 0), 0x19: ('daa', 0), 0x1B: ('aba', 0),
        0x30: ('tsx', 0), 0x31: ('ins', 0), 0x32: ('pula', 0),
        0x33: ('pulb', 0), 0x34: ('des', 0), 0x35: ('txs', 0),
        0x36: ('psha', 0), 0x37: ('pshb', 0), 0x39: ('rts', 0),
        0x3B: ('rti', 0), 0x3E: ('wai', 0), 0x3F: ('swi', 0),
        0x60: ('neg', 4), 0x63: ('com', 4), 0x64: ('lsr', 4),
        0x66: ('ror', 4), 0x67: ('asr', 4), 0x68: ('asl', 4),
        0x69: ('rol', 4), 0x6A: ('dec', 4), 0x6C: ('inc', 4),
        0x6D: ('tst', 4), 0x6E: ('jmp', 4), 0x6F: ('clr', 4),
        0x70: ('neg', 3), 0x73: ('com', 3), 0x74: ('lsr', 3),
        0x76: ('ror', 3), 0x77: ('asr', 3), 0x78: ('asl', 3),
        0x79: ('rol', 3), 0x7A: ('dec', 3), 0x7C: ('inc', 3),
        0x7D: ('tst', 3), 0x7E: ('jmp', 3), 0x7F: ('clr', 3),
    }
    if d in table:
        return (table[d][0], table[d][1], bool(d & 0x40))
    if 0x20 <= d <= 0x2F and d != 0x21:
        br = ['bra', None, 'bhi', 'bls', 'bcc', 'bcs', 'bne', 'beq',
              'bvc', 'bvs', 'bpl', 'bmi', 'bge', 'blt', 'bgt', 'ble'][d - 0x20]
        return (br, 5, False)
    if (d & 0xF0) in (0x40, 0x50) and (d & 0x0F) in (0, 3, 4, 6, 7, 8, 9,
                                                     10, 12, 13, 15):
        rmw = {0: 'neg', 3: 'com', 4: 'lsr', 6: 'ror', 7: 'asr', 8: 'asl',
               9: 'rol', 10: 'dec', 12: 'inc', 13: 'tst', 15: 'clr'}[d & 0x0F]
        # 0x4x = ACCA, 0x5x = ACCB: the discriminator is bit 4, not bit 6
        return (rmw, 0, not (d & 0x10))
    return ('nop', 0, False)  # unassigned: 1-byte no-op


def add(a, b, ci):
    s = a + b + ci
    r = s & 0xFF
    c = 1 if s > 0xFF else 0
    # overflow for addition: sign changes between operands and result,
    # (a^r)&(b^r); (a^b)&(a^r) is the subtract formula
    v = 1 if ((a ^ r) & (b ^ r)) & 0x80 else 0
    h = 1 if (a & 0xF) + (b & 0xF) + ci > 0xF else 0
    return r, c, v, h


def sub(a, b, bi):
    t = a - b - bi
    r = t & 0xFF
    # the 6800 subtract carry IS the borrow (PRM: set if |M| > |ACCX|);
    # this differs from the 6502's inverted convention
    c = 1 if t < 0 else 0
    v = 1 if ((a ^ b) & (a ^ r)) & 0x80 else 0
    return r, c, v


def daa(val, h, c_in):
    lo, hi = val & 0xF, val >> 4
    nd = lo > 9 or h
    md = bool(c_in) or hi > 9 or (hi == 9 and lo > 9)
    addend = (0x60 if md else 0) | (0x06 if nd else 0)
    return (val + addend) & 0xFF, md


class ISS:
    def __init__(self):
        self.mem = bytearray(65536)
        self.a = self.b = 0
        self.ix = self.sp = self.pc = 0
        self.cc = 0xD0            # reset state: bits 7-6 set, I set
        self.irq = False
        self.nmi = False
        self.halted = False
        self.done = False
        self.trace = []
        self.pending = {}       # pc -> [actions]

    def reset(self):
        """Reset sequence: PC loads from the $FFFE/$FFFF vector pair."""
        self.pc = ((self.mem[VEC_RST] << 8) | self.mem[VEC_RST + 1]) \
            & 0xFFFF
        self.cc = 0xD0
        self.halted = False

    def push(self, val):
        self.mem[self.sp] = val & 0xFF
        self.sp = (self.sp - 1) & 0xFFFF

    def pull(self):
        self.sp = (self.sp + 1) & 0xFFFF
        return self.mem[self.sp]

    def fetch8(self):
        v = self.mem[self.pc]
        self.pc = (self.pc + 1) & 0xFFFF
        return v

    def fetch16(self):
        hi = self.fetch8()
        lo = self.fetch8()
        return (hi << 8) | lo

    def eff(self, mode):
        if mode == 2:
            return self.fetch8()          # direct
        if mode == 3:
            return self.fetch16()         # extended
        if mode == 4:
            off = self.fetch8()
            return (self.ix + off) & 0xFFFF  # indexed
        raise ValueError(f'no ea for mode {mode}')

    def set_nz8(self, r):
        self.cc = (self.cc & ~(FN | FZ)) | (FN if r & 0x80 else 0) \
            | (FZ if r == 0 else 0)

    def set_nz16(self, r):
        self.cc = (self.cc & ~(FN | FZ)) | (FN if r & 0x8000 else 0) \
            | (FZ if r == 0 else 0)

    def accv(self, acc):
        return self.a if acc else self.b

    def set_acc(self, acc, r):
        if acc:
            self.a = r
        else:
            self.b = r

    def rmw_flags(self, r, c, v):
        self.cc = (self.cc & ~(FC | FV | FN | FZ)) \
            | (FC if c else 0) | (FV if v else 0)
        self.set_nz8(r)

    def alu8(self, opname, val):
        acc = self.cur_acc
        x = self.accv(acc)
        if opname == 'lda':
            self.set_acc(acc, val)
            self.set_nz8(val)
            self.cc &= ~FV
        elif opname in ('and', 'bit'):
            r = x & val
            self.set_nz8(r)
            self.cc &= ~FV
            if opname == 'and':
                self.set_acc(acc, r)
        elif opname == 'ora':
            r = x | val
            self.set_nz8(r)
            self.cc &= ~FV
            self.set_acc(acc, r)
        elif opname == 'eor':
            r = x ^ val
            self.set_nz8(r)
            self.cc &= ~FV
            self.set_acc(acc, r)
        elif opname == 'add':
            r, c, v, h = add(x, val, 0)
            self.cc = (self.cc & ~(FC | FV | FH)) \
                | (FC if c else 0) | (FV if v else 0) | (FH if h else 0)
            self.set_nz8(r)
            self.set_acc(acc, r)
        elif opname == 'adc':
            r, c, v, h = add(x, val, 1 if self.cc & FC else 0)
            self.cc = (self.cc & ~(FC | FV | FH)) \
                | (FC if c else 0) | (FV if v else 0) | (FH if h else 0)
            self.set_nz8(r)
            self.set_acc(acc, r)
        elif opname == 'sub':
            r, c, v = sub(x, val, 0)
            self.cc = (self.cc & ~(FC | FV)) \
                | (FC if c else 0) | (FV if v else 0)
            self.set_nz8(r)
            self.set_acc(acc, r)
        elif opname == 'sbc':
            # SBC subtracts C directly (PRM: ACCX - M - C)
            r, c, v = sub(x, val, 1 if self.cc & FC else 0)
            self.cc = (self.cc & ~(FC | FV)) \
                | (FC if c else 0) | (FV if v else 0)
            self.set_nz8(r)
            self.set_acc(acc, r)
        elif opname == 'cmp':
            r, c, v = sub(x, val, 0)
            self.cc = (self.cc & ~(FC | FV)) \
                | (FC if c else 0) | (FV if v else 0)
            self.set_nz8(r)

    def alu16(self, opname, val):
        if opname in ('ldx', 'lds'):
            if opname == 'ldx':
                self.ix = val
            else:
                self.sp = val
            self.set_nz16(val)
            self.cc &= ~FV
        elif opname == 'cpx':
            xh = (self.ix >> 8) & 0xFF
            mh = (val >> 8) & 0xFF
            r = (self.ix - val) & 0xFFFF
            rh = (r >> 8) & 0xFF
            self.set_nz16(r)
            v = 1 if ((xh ^ mh) & (xh ^ rh)) & 0x80 else 0
            self.cc = (self.cc & ~FV) | (FV if v else 0)

    def rmw8(self, opname, val):
        if opname == 'neg':
            r = (-val) & 0xFF
            c = 1 if val != 0 else 0
            v = 1 if val == 0x80 else 0
        elif opname == 'com':
            r = (~val) & 0xFF
            c, v = 1, 0
        elif opname == 'lsr':
            r = val >> 1
            c, v = val & 1, val & 1
        elif opname == 'ror':
            c = val & 1
            r = ((0x80 if self.cc & FC else 0) | (val >> 1)) & 0xFF
            v = ((r >> 7) & 1) ^ c
        elif opname == 'asr':
            c = val & 1
            r = (val & 0x80) | (val >> 1)
            v = ((val >> 7) & 1) ^ c
        elif opname == 'asl':
            c = (val >> 7) & 1
            r = (val << 1) & 0xFF
            v = ((r >> 7) & 1) ^ c
        elif opname == 'rol':
            c = (val >> 7) & 1
            r = ((val << 1) & 0xFF) | (0x01 if self.cc & FC else 0)
            v = ((r >> 7) & 1) ^ c
        elif opname == 'dec':
            r = (val - 1) & 0xFF
            c = 1 if self.cc & FC else 0
            v = 1 if val == 0x80 else 0
        elif opname == 'inc':
            r = (val + 1) & 0xFF
            c = 1 if self.cc & FC else 0
            v = 1 if val == 0x7F else 0
        elif opname == 'tst':
            r, c, v = val, 0, 0
        elif opname == 'clr':
            r, c, v = 0, 0, 0
        self.rmw_flags(r, c, v)
        return r

    def branch(self, opname, off):
        cc = self.cc
        nb, zb, vb, cb = (bool(cc & FN), bool(cc & FZ),
                          bool(cc & FV), bool(cc & FC))
        take = {
            'bra': True,
            'bcc': not cb, 'bcs': cb,
            'bne': not zb, 'beq': zb,
            'bvc': not vb, 'bvs': vb,
            'bpl': not nb, 'bmi': nb,
            'bge': nb == vb, 'blt': nb != vb,
            'bgt': (not zb) and (nb == vb),
            'ble': zb or (nb != vb),
            'bhi': (not cb) and (not zb),
            'bls': cb or zb,
        }[opname]
        if take:
            self.pc = (self.pc + ((off ^ 0x80) - 0x80)) & 0xFFFF

    def io_write(self, addr, val):
        if addr == IO_PORT:
            if val == 0:
                self.irq = True
            elif val == 1:
                self.irq = False
            elif val == 2:
                self.nmi = True
            elif val == 0xAA:
                self.done = True
                self.done_pc = self.pc
            else:
                self.done_port_log = getattr(self, 'done_port_log', [])
                if len(self.done_port_log) < 8:
                    self.done_port_log.append((self.pc, val))

    def push_frame(self):
        self.push(self.pc & 0xFF)
        self.push((self.pc >> 8) & 0xFF)
        self.push(self.ix & 0xFF)
        self.push((self.ix >> 8) & 0xFF)
        self.push(self.a)
        self.push(self.b)
        self.push(self.cc | CMASK)

    def vector_to(self, vec):
        self.pc = ((self.mem[vec] << 8) | self.mem[vec + 1]) & 0xFFFF

    def service_interrupt(self):
        if self.nmi:
            vec = VEC_NMI
            self.nmi = False
        else:
            vec = VEC_IRQ
        self.push_frame()
        self.cc |= FI
        self.vector_to(vec)

    def apply(self, acts):
        for action, delay in acts:
            if action == 0:
                self.irq = True
            elif action == 1:
                self.irq = False
            elif action == 2:
                self.nmi = True

    def step(self):
        if self.done:
            return
        if self.halted:
            # waiting from WAI: wake on NMI, or IRQ with I clear.
            # No trace entry: the RTL asserts sync_o only on fetches.
            acts = self.pending.pop(self.pc, None)
            if acts:
                self.apply(acts)
            if self.nmi or (self.irq and not self.cc & FI):
                self.halted = False
                self.cc |= FI
                self.vector_to(VEC_NMI if self.nmi else VEC_IRQ)
                if self.nmi:
                    self.nmi = False
            return
        if self.nmi or (self.irq and not self.cc & FI):
            # preemption: the interrupted fetch never executes, so no
            # boundary record and no trigger pop (matches the RTL, whose
            # sync_o only fires on real fetches)
            self.service_interrupt()
            return
        # scripted external event: fires after the instruction at its pc
        acts = self.pending.pop(self.pc, None)
        # instruction boundary record (state before execution)
        self.trace.append((self.pc, self.a, self.b, self.ix, self.sp,
                           self.cc))
        d = self.mem[self.pc]
        name, mode, acc = dec(d)
        self.cur_acc = acc
        self.pc = (self.pc + 1) & 0xFFFF
        if mode == 0:
            self.inherent(name, acc)
        elif mode == 5:
            off = self.fetch8()
            if name == 'bsr':
                ret = self.pc
                self.push(ret & 0xFF)
                self.push((ret >> 8) & 0xFF)
                self.pc = (self.pc + ((off ^ 0x80) - 0x80)) & 0xFFFF
            else:
                self.branch(name, off)
        else:
            if name in ('ldx', 'lds', 'cpx') and mode == 1:
                val = self.fetch16()
                self.alu16(name, val)
            elif name in ('stx', 'sts'):
                ea = self.eff(mode)
                v = self.sp if name == 'sts' else self.ix
                self.mem[ea] = (v >> 8) & 0xFF
                self.mem[(ea + 1) & 0xFFFF] = v & 0xFF
                self.set_nz16(v)
                self.cc &= ~FV
                self.io_write(ea, self.mem[ea])
                self.io_write((ea + 1) & 0xFFFF, self.mem[(ea + 1) & 0xFFFF])
            elif name == 'sta':
                ea = self.eff(mode)
                self.mem[ea] = self.accv(acc)
                self.io_write(ea, self.mem[ea])
            elif name == 'jmp':
                self.pc = self.eff(mode)
            elif name == 'jsr':
                ea = self.eff(mode)
                ret = self.pc
                self.push(ret & 0xFF)
                self.push((ret >> 8) & 0xFF)
                self.pc = ea
            elif name in ('ldx', 'lds', 'cpx'):
                ea = self.eff(mode)
                val = (self.mem[ea] << 8) | self.mem[(ea + 1) & 0xFFFF]
                self.alu16(name, val)
            elif name in ('neg', 'com', 'lsr', 'ror', 'asr', 'asl', 'rol',
                          'dec', 'inc', 'tst', 'clr'):
                ea = self.eff(mode)
                r = self.rmw8(name, self.mem[ea])
                if name != 'tst':
                    self.mem[ea] = r
                    self.io_write(ea, r)
            elif mode == 1:
                self.alu8(name, self.fetch8())
            else:
                ea = self.eff(mode)
                self.alu8(name, self.mem[ea])
        if acts:
            self.apply(acts)

    def inherent(self, name, acc):
        if name == 'tap':
            self.cc = CMASK | (self.a & (FH | FI | FN | FZ | FV | FC))
        elif name == 'tpa':
            self.a = self.cc
        elif name == 'inx':
            self.ix = (self.ix + 1) & 0xFFFF
            self.cc = (self.cc & ~FZ) | (FZ if self.ix == 0 else 0)
        elif name == 'dex':
            self.ix = (self.ix - 1) & 0xFFFF
            self.cc = (self.cc & ~FZ) | (FZ if self.ix == 0 else 0)
        elif name == 'clv':
            self.cc &= ~FV
        elif name == 'sev':
            self.cc |= FV
        elif name == 'clc':
            self.cc &= ~FC
        elif name == 'sec':
            self.cc |= FC
        elif name == 'cli':
            self.cc &= ~FI
        elif name == 'sei':
            self.cc |= FI
        elif name == 'sba':
            r, c, v = sub(self.b, self.a, 0)
            self.b = r
            self.cc = (self.cc & ~(FC | FV)) \
                | (FC if c else 0) | (FV if v else 0)
            self.set_nz8(r)
        elif name == 'cba':
            r, c, v = sub(self.b, self.a, 0)
            self.cc = (self.cc & ~(FC | FV)) \
                | (FC if c else 0) | (FV if v else 0)
            self.set_nz8(r)
        elif name == 'tab':
            self.b = self.a
            self.set_nz8(self.a)
            self.cc &= ~FV
        elif name == 'tba':
            self.a = self.b
            self.set_nz8(self.b)
            self.cc &= ~FV
        elif name == 'daa':
            r, c = daa(self.a, 1 if self.cc & FH else 0,
                       1 if self.cc & FC else 0)
            self.a = r
            self.cc = (self.cc & ~FC) | (FC if c else 0)
            self.set_nz8(r)
        elif name == 'aba':
            r, c, v, h = add(self.a, self.b, 0)
            self.a = r
            self.cc = (self.cc & ~(FC | FV | FH)) \
                | (FC if c else 0) | (FV if v else 0) | (FH if h else 0)
            self.set_nz8(r)
        elif name == 'tsx':
            self.ix = (self.sp + 1) & 0xFFFF
        elif name == 'txs':
            self.sp = (self.ix - 1) & 0xFFFF
        elif name == 'ins':
            self.sp = (self.sp + 1) & 0xFFFF
        elif name == 'des':
            self.sp = (self.sp - 1) & 0xFFFF
        elif name == 'psha':
            self.push(self.a)
        elif name == 'pshb':
            self.push(self.b)
        elif name == 'pula':
            self.a = self.pull()
        elif name == 'pulb':
            self.b = self.pull()
        elif name == 'rts':
            hi = self.pull()
            lo = self.pull()
            self.pc = (hi << 8) | lo
        elif name == 'rti':
            self.cc = CMASK | (self.pull() & (FH | FI | FN | FZ | FV | FC))
            self.b = self.pull()
            self.a = self.pull()
            self.ix = (self.pull() << 8) | self.pull()
            hi = self.pull()
            lo = self.pull()
            self.pc = (hi << 8) | lo
        elif name == 'wai':
            self.push_frame()
            self.halted = True
        elif name == 'swi':
            self.push_frame()
            self.cc |= FI
            self.vector_to(VEC_SWI)
        elif name in ('neg', 'com', 'lsr', 'ror', 'asr', 'asl', 'rol',
                      'dec', 'inc', 'tst', 'clr'):
            r = self.rmw8(name, self.a if acc else self.b)
            if name == 'clr':
                self.set_acc(acc, 0)
            elif name != 'tst':
                self.set_acc(acc, r)
        # 'nop': nothing


# ---------------------------------------------------------------------------
# Directed program builder (fixed layout, no symbol fixups needed)
# ---------------------------------------------------------------------------
rng = LCG(0x6800)


def imm8():
    return rng.choice([0x00, 0x01, 0x02, 0x7F, 0x80, 0x81, 0xFF, 0x7E,
                       0xFE, 0x40, 0x3F, 0xC0, rng.below(256)])


class Prog:
    def __init__(self, org):
        self.org = org
        self.pc = org
        self.buf = {}

    def emit(self, *bs):
        for x in bs:
            self.buf[self.pc] = x & 0xFF
            self.pc += 1

    def emit_at(self, addr, *bs):
        save = self.pc
        self.pc = addr
        self.emit(*bs)
        self.pc = save


def documented_opcodes():
    """The 197 valid machine codes of M68PRM Table 3-1."""
    doc = set()
    for d in range(256):
        if d & 0x80:
            row, col = (d >> 4) & 7, d & 0x0F
            if col in (0, 1, 2, 4, 5, 6, 8, 9, 10, 11):
                doc.add(d)              # 8-bit ALU rows (no STA-imm: col 7)
            if col == 7 and (row & 3) != 0:
                doc.add(d)              # STA DIR/IND/EXT
            if col == 12 and row <= 3:
                doc.add(d)              # CPX
            if col == 13 and (row == 0 or row in (2, 3)):
                doc.add(d)              # BSR, JSR
            if col == 14:
                doc.add(d)              # LDS/LDX
            if col == 15 and (row & 3) != 0:
                doc.add(d)              # STS/STX DIR/IND/EXT (no IMM form)
        else:
            name, mode, _ = dec(d)
            if (name, mode) != ('nop', 0) or d == 0x01:
                doc.add(d)
    return doc


def main():
    iss = ISS()
    m = iss.mem

    # ---- vectors ----
    for addr, hi, lo in ((VEC_RST, MAIN >> 8, MAIN & 0xFF),
                         (VEC_IRQ, IRQ_H >> 8, IRQ_H & 0xFF),
                         (VEC_SWI, SWI_H >> 8, SWI_H & 0xFF),
                         (VEC_NMI, NMI_H >> 8, NMI_H & 0xFF)):
        m[addr] = hi
        m[addr + 1] = lo

    # ---- data areas ----
    for a in range(0x0040, 0x0100):
        m[a] = rng.below(256)
    for a in range(0x2000, 0x3000):
        m[a] = rng.below(256)

    p = Prog(MAIN)

    # register/scratch conventions:
    #   SP = $2F00, IX = $2000, zero page = $0040..$00FF
    p.emit(0x8E, 0x2F, 0x00)          # LDS #$2F00
    p.emit(0xCE, 0x20, 0x00)          # LDX #$2000

    alu8 = [
        (0x80, 0x90, 0xB0, 0xA0), (0xC0, 0xD0, 0xF0, 0xE0),  # SUB
        (0x81, 0x91, 0xB1, 0xA1), (0xC1, 0xD1, 0xF1, 0xE1),  # CMP
        (0x82, 0x92, 0xB2, 0xA2), (0xC2, 0xD2, 0xF2, 0xE2),  # SBC
        (0x84, 0x94, 0xB4, 0xA4), (0xC4, 0xD4, 0xF4, 0xE4),  # AND
        (0x85, 0x95, 0xB5, 0xA5), (0xC5, 0xD5, 0xF5, 0xE5),  # BIT
        (0x86, 0x96, 0xB6, 0xA6), (0xC6, 0xD6, 0xF6, 0xE6),  # LDA
        (None, 0x97, 0xB7, 0xA7), (None, 0xD7, 0xF7, 0xE7),  # STA
        (0x88, 0x98, 0xB8, 0xA8), (0xC8, 0xD8, 0xF8, 0xE8),  # EOR
        (0x89, 0x99, 0xB9, 0xA9), (0xC9, 0xD9, 0xF9, 0xE9),  # ADC
        (0x8A, 0x9A, 0xBA, 0xAA), (0xCA, 0xDA, 0xFA, 0xEA),  # ORA
        (0x8B, 0x9B, 0xBB, 0xAB), (0xCB, 0xDB, 0xFB, 0xEB),  # ADD
    ]

    def setup_op():
        # pseudorandom flag/accumulator state before the target instruction
        if rng.below(2):
            p.emit(0x0C if rng.below(2) else 0x0D)      # CLC / SEC
        p.emit(0x86, imm8())                             # LDAA #imm
        p.emit(0xC6, imm8())                             # LDAB #imm

    def emit_mode(opb, mode):
        if mode == 1:
            p.emit(opb, imm8())
        elif mode == 2:
            p.emit(opb, rng.range(0x40, 0x100))
        elif mode == 3:
            p.emit(opb, 0x20, rng.below(0x100))
        else:
            p.emit(opb, rng.below(0x100))

    for i in range(0, len(alu8), 2):
        for ops in (alu8[i], alu8[i + 1]):
            for mode, opb in zip((1, 2, 3, 4), ops):
                if opb is None:
                    continue
                setup_op()
                emit_mode(opb, mode)
                p.emit(0x97, 0x40)            # STAA $40
                p.emit(0xD7, 0x41)            # STAB $41

    # 16-bit loads/compares in all modes. LDS/LDX are followed by an
    # immediate restore so the random values cannot corrupt the stack or
    # later indexed addressing (CPX changes nothing).
    for opb, mode in [(0xCE, 1), (0xDE, 2), (0xFE, 3), (0xEE, 4),
                      (0x8E, 1), (0x9E, 2), (0xBE, 3), (0xAE, 4),
                      (0x8C, 1), (0x9C, 2), (0xBC, 3), (0xAC, 4)]:
        setup_op()
        if mode == 1:
            p.emit(opb, imm8(), imm8())
        elif mode == 2:
            p.emit(opb, rng.range(0x40, 0xFC))
        elif mode == 3:
            p.emit(opb, 0x20, rng.below(0xFE))
        else:
            p.emit(opb, rng.below(0xFE))
        if opb in (0xCE, 0xDE, 0xFE, 0xEE):
            p.emit(0xCE, 0x20, 0x00)      # LDX #$2000 (restore)
        elif opb in (0x8E, 0x9E, 0xBE, 0xAE):
            p.emit(0x8E, 0x2F, 0x00)      # LDS #$2F00 (restore)
    # 16-bit stores in all modes
    for opb, mode in [(0xDF, 2), (0xFF, 3), (0xEF, 4),
                      (0x9F, 2), (0xBF, 3), (0xAF, 4)]:
        setup_op()
        if mode == 2:
            p.emit(opb, rng.range(0x40, 0xFE))
        elif mode == 3:
            p.emit(opb, 0x20, rng.below(0xFE))
        else:
            p.emit(opb, rng.below(0xFE))

    # RMW ops on accumulators
    for opb in (0x40, 0x43, 0x44, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4C,
                0x4D, 0x4F, 0x50, 0x53, 0x54, 0x56, 0x57, 0x58, 0x59,
                0x5A, 0x5C, 0x5D, 0x5F):
        setup_op()
        p.emit(opb)
        p.emit(0x97, 0x42)

    # RMW ops on memory (indexed $6x + extended $7x)
    for opb in (0x60, 0x63, 0x64, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6C,
                0x6D, 0x6F, 0x70, 0x73, 0x74, 0x76, 0x77, 0x78, 0x79,
                0x7A, 0x7C, 0x7D, 0x7F):
        setup_op()
        if opb & 0x20:
            p.emit(opb, rng.below(0x100))          # indexed
        else:
            p.emit(opb, 0x20, rng.below(0x100))    # extended
        p.emit(0xB6, 0x20, 0x00)                   # LDAA $2000 (park)

    # transfers / status / index and stack arithmetic (RTS is exercised by
    # the JSR/BSR round trip below; a bare RTS here would pull garbage)
    for opb in (0x01, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D,
                0x0E, 0x0F, 0x10, 0x11, 0x16, 0x17, 0x1B, 0x30, 0x31,
                0x34, 0x35):
        setup_op()
        p.emit(opb)
    p.emit(0x8E, 0x2F, 0x00)          # LDS #$2F00 (restore discipline)
    p.emit(0xCE, 0x20, 0x00)          # LDX #$2000
    # TAP/TPA round trip with random flag bytes
    for _ in range(8):
        p.emit(0x86, rng.choice([0x00, 0x0F, 0x1F, 0x2F, 0x3F, 0x55,
                                 0xAA, 0xFF]))
        p.emit(0x06)      # TAP
        p.emit(0x07)      # TPA
        p.emit(0x97, 0x43)
        p.emit(0x0E)      # CLI (keep IRQ usable afterwards)
    # PSH/PUL on both accumulators, exercising the stack
    for _ in range(6):
        p.emit(0x86, imm8())
        p.emit(0xC6, imm8())
        p.emit(0x36)      # PSHA
        p.emit(0x37)      # PSHB
        p.emit(0x32)      # PULA
        p.emit(0x33)      # PULB
        p.emit(0x97, 0x44)
        p.emit(0xD7, 0x45)

    # JSR extended + BSR/RTS round trip
    setup_op()
    p.emit(0xBD, 0x0F, 0x00)          # JSR $0F00 (subroutine, RTS)
    setup_op()
    p.emit(0xCE, 0x0F, 0x01)          # LDX #$0F01
    p.emit(0xAD, 0x00)                # JSR $00,X -> $0F01 (subroutine)
    p.emit(0x8D, 0x02)                # BSR +2
    p.emit(0x39)                      # RTS (skipped when BSR taken)
    p.emit(0x97, 0x46)                # STAA $46 (BSR/JSR returns land here)

    # JMP extended + indexed: jump to $2F80/$2F84 islands (above the
    # $2F00 stack region) that jump back to the continuation
    setup_op()
    p.emit(0x7E, 0x2F, 0x80)          # JMP $2F80
    p.emit(0x97, 0x50)                # skipped when the JMP is taken
    cont1 = p.pc
    setup_op()
    p.emit(0xCE, 0x2F, 0x04)          # LDX #$2F04
    p.emit(0x6E, 0x80)                # JMP $80,X -> $2F84
    p.emit(0x97, 0x51)                # skipped when the JMP is taken
    cont2 = p.pc

    # DAA over the interesting BCD corners (kept small: the program must
    # stay below the $0F00 subroutine page)
    vals = [0x00, 0x01, 0x09, 0x0A, 0x0F, 0x10, 0x15, 0x19, 0x1A, 0x50,
            0x59, 0x5A, 0x90, 0x99, 0x9A, 0xF0, 0xF9, 0xFA]
    for _ in range(60):
        if rng.below(2):
            p.emit(0x0D)              # SEC
        else:
            p.emit(0x0C)              # CLC
        p.emit(0x86, rng.choice(vals))
        p.emit(0x8B, rng.choice(vals))  # ADDA # (sets H)
        p.emit(0x19)                    # DAA
        p.emit(0x97, 0x47)
    for _ in range(40):
        p.emit(0x0C if rng.below(2) else 0x0D)
        p.emit(0x86, rng.choice(vals))
        p.emit(0xC6, rng.choice(vals))
        p.emit(0x1B)                    # ABA
        p.emit(0x19)                    # DAA
        p.emit(0x97, 0x48)

    # branches: deterministic pass over every condition, then random ones;
    # flag patterns from CMPA force taken/not-taken paths
    branch_ops = [0x20, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29,
                  0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F]
    for opb in branch_ops + [rng.choice(branch_ops) for _ in range(45)]:
        setup_op()
        p.emit(0x81, imm8())          # CMPA #imm
        p.emit(opb, 0x02)             # branch over the next store
        p.emit(0x97, 0x49)
        p.emit(0x97, 0x4A)

    # ---- interrupt scenarios ----
    setup_op()
    p.emit(0x3F)                      # SWI -> $F100 handler
    p.emit(0x97, 0x4B)
    # WAI with NMI wake
    p.emit(0x0C)                      # CLC (I clear)
    wai_pc = p.pc
    p.emit(0x3E)                      # WAI (NMI via trigger)
    p.emit(0x97, 0x4C)
    # WAI with IRQ wake (I clear)
    p.emit(0x0E)                      # CLI
    wai2_pc = p.pc
    p.emit(0x3E)                      # WAI (IRQ via trigger)
    p.emit(0x97, 0x4D)
    # IRQ preemption of a straight-line run
    p.emit(0x0E)                      # CLI
    irq_pc = p.pc
    p.emit(0x86, 0x00)                # LDAA #0
    p.emit(0xB7, 0xE0, 0x00)          # STAA $E000 (assert IRQ)
    for _ in range(6):
        p.emit(0x4C)                  # INCA (handler counts)
    p.emit(0x97, 0x4E)                # STAA $4E
    # nested IRQ: handler re-enables; second level preempts
    nested_pc = p.pc
    p.emit(0x86, 0x00)
    p.emit(0xB7, 0xE0, 0x00)          # assert IRQ again
    for _ in range(8):
        p.emit(0x4C)
    p.emit(0x97, 0x4F)
    # done
    p.emit(0x86, 0xAA)
    p.emit(0xB7, 0xE0, 0x00)          # STAA $E000 -> done
    p.emit(0x20, 0xFE)                # BRA * (safety loop)

    # ---- handlers ----
    # IRQ handler $F000: INC $E101; on every even count deassert the
    # level IRQ (so each scripted assertion costs exactly two entries);
    # RTI. A scripted NMI pulse inside the handler exercises nesting.
    p.emit_at(IRQ_H,
              0x7C, 0xE1, 0x01,       # INC $E101
              0xB6, 0xE1, 0x01,       # LDAA $E101
              0x84, 0x01,             # ANDA #$01
              0x26, 0x05,             # BNE +5 -> RTI
              0x86, 0x01,             # LDAA #$01
              0xB7, 0xE0, 0x00,       # STAA $E000 (deassert IRQ)
              0x0D,                   # SEC (marker)
              0x3B)                   # RTI
    # SWI handler $F100: INC $E102; RTI
    p.emit_at(SWI_H, 0x7C, 0xE1, 0x02, 0x3B)
    # NMI handler $F200: INC $E103; RTI
    p.emit_at(NMI_H, 0x7C, 0xE1, 0x03, 0x3B)
    # subroutines used by the JSR tests: TPA; PSHA; PULA; RTS
    if p.pc > 0x0F00:
        raise SystemExit(f'program overflows the subroutine page: '
                         f'{p.pc:04X}')
    p.emit_at(0x0F00, 0x07, 0x36, 0x32, 0x39)
    p.emit_at(0x0F01, 0x07, 0x36, 0x32, 0x39)
    # JMP islands in the extended-data page: jump back to the continuation
    p.emit_at(0x2F80, 0x7E, (cont1 >> 8) & 0xFF, cont1 & 0xFF)
    p.emit_at(0x2F84, 0x7E, (cont2 >> 8) & 0xFF, cont2 & 0xFF)

    for a, v in p.buf.items():
        m[a] = v

    # ---- external trigger script (mirrored by the RTL testbench) ----
    triggers = [
        (wai_pc, 2, 8),      # NMI pulse while WAI is waiting
        (wai2_pc, 0, 8),     # IRQ low while WAI is waiting
        (IRQ_H, 2, 3),       # NMI pulse inside the IRQ handler (nesting)
        (irq_pc, 0, 1),      # IRQ arrives right after the LDAA #0
        (nested_pc, 0, 1),   # second preemption scenario
    ]

    # ---- run the oracle ----
    for pc, action, delay in triggers:
        iss.pending.setdefault(pc, []).append((action, delay))

    iss.mem = bytearray(m)    # working copy; m remains the initial image
    iss.reset()
    limit = 400000
    steps = 0
    while not iss.done and steps < limit:
        iss.step()
        steps += 1
    if not iss.done:
        tail = ' | '.join(f'{rec[0]:04x}:{rec[1]:02x}/{rec[2]:02x}/'
                          f'{rec[3]:04x}/{rec[4]:04x}/{rec[5]:02x}'
                          for rec in iss.trace[-30:])
        # first trace entry whose pc is outside program/handler space
        zp = next((i for i, rec in enumerate(iss.trace)
                   if not (0x0100 <= rec[0] <= 0x0F10 or 0xF000 <= rec[0]
                           <= 0xF210)), None)
        ctx = ' | '.join(f'{rec[0]:04x}:{rec[1]:02x}/{rec[2]:02x}/'
                         f'{rec[3]:04x}/{rec[4]:04x}/{rec[5]:02x}'
                         for rec in iss.trace[max(0, zp - 14):zp + 6]) \
            if zp is not None else 'n/a'
        raise SystemExit('oracle did not reach the done marker '
                         f'(steps={steps}, pc={iss.pc:04X}); '
                         f'zero-page entry at trace[{zp}]:\n{ctx}\n'
                         f'last:\n{tail}')
    print(f'done fired at pc={getattr(iss, "done_pc", 0):04X}; '
          f'port log={getattr(iss, "done_port_log", [])}')
    print('tail:', ' | '.join(f'{rec[0]:04x}:{rec[1]:02x}/{rec[2]:02x}/'
                              f'{rec[3]:04x}/{rec[4]:04x}/{rec[5]:02x}'
                              for rec in iss.trace[-25:]))

    # ---- coverage self-audit ----
    seen = set()
    for rec in iss.trace:
        seen.add(m[rec[0]])
    docs = documented_opcodes()
    missing = docs - seen
    print(f'oracle trace: {len(iss.trace)} instructions, {steps} steps, '
          f'{len(docs)} documented opcodes, '
          f'missing {sorted(f"{x:02x}" for x in missing)}')
    if len(docs) != 197:
        raise SystemExit(f'decoder documents {len(docs)} opcodes, '
                         'expected 197 per M68PRM Table 3-1')
    if missing:
        raise SystemExit(f'opcodes never executed: '
                         f'{sorted(f"{x:02x}" for x in missing)}')

    # ---- emit artifacts (single-shot pathlib writes) ----
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    vec_txt = ''.join(' '.join(f'{x:04x}' for x in rec) + '\n'
                      for rec in iss.trace)
    vec_txt += 'ffff ffff ffff ffff ffff ffff\n'  # terminator record
    (OUT_ROOT / 'vectors.hex').write_text(vec_txt)
    mem_txt = ''.join(f'{b:02x}\n' for b in m)
    (OUT_ROOT / 'mem.hex').write_text(mem_txt)
    gold_txt = ''.join(f'{b:02x}\n' for b in iss.mem)
    (OUT_ROOT / 'gold_mem.hex').write_text(gold_txt)
    trig_txt = ''.join(f'{pc:04x} {action:02x} {delay:04x}\n'
                       for pc, action, delay in triggers)
    (OUT_ROOT / 'triggers.hex').write_text(trig_txt)
    print('oracle vectors written to', OUT_ROOT)


if __name__ == '__main__':
    main()
