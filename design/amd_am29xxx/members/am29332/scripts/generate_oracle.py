#!/usr/bin/env python3
"""External Am29332 functional oracle; no RTL parsing or DUT logic.

Sources: AMD Am29332 Instruction Manual (1987) Chapter 1 summary tables and
Figure 3 status map, Chapter 2 detailed instruction descriptions (124 defined
opcodes), Appendix A BCD rules and worked examples 1-13, Appendix B modified
Booth multiply and nonrestoring divide flow charts with the 65hx48h multiply
trace and the 75h/02h divide trace, and the Am29332 datasheet PIN DESCRIPTION
section in the 1988 data book (signal-level BOROW/RS/HOLD/M/m semantics).
See spec/spec.md for the full contract and assumption ledger.

The model steps through every drive the testbench performs, including the
PASS-STAT / PASS-Q readback rows appended after each instruction row, keeping
status and Q registers in lockstep. Outputs are checked before each vector's
clock edge; the edge then updates the registers unless HOLD is HIGH.

--check-table re-derives every curated row's expected columns from the model
(the transcription guard for the manual's worked examples); --write-table
emits the full vector stream (curated + algorithm + seeded random rows).
"""
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
M32 = 0xFFFFFFFF

OPNAMES = {
    0x00: "ZERO-EXTA", 0x01: "ZERO-EXTB", 0x02: "SIGN-EXTA", 0x03: "SIGN-EXTB",
    0x04: "PASS-STAT", 0x05: "PASS-Q", 0x06: "LOADQ-A", 0x07: "LOADQ-B",
    0x08: "NOT-A", 0x09: "NOT-B", 0x0A: "NEG-A", 0x0B: "NEG-B",
    0x0C: "PRIOR-A", 0x0D: "PRIOR-B", 0x0E: "MERGEA-B", 0x0F: "MERGEB-A",
    0x10: "DECR-A", 0x11: "DECR-B", 0x12: "INCR-A", 0x13: "INCR-B",
    0x14: "DECR2-A", 0x15: "DECR2-B", 0x16: "INCR2-A", 0x17: "INCR2-B",
    0x18: "DECR4-A", 0x19: "DECR4-B", 0x1A: "INCR4-A", 0x1B: "INCR4-B",
    0x1C: "LDSTAT-A", 0x1D: "LDSTAT-B",
    0x20: "DN1-0F-A", 0x21: "DN1-0F-B", 0x22: "DN1-0F-AQ", 0x23: "DN1-0F-BQ",
    0x24: "DN1-1F-A", 0x25: "DN1-1F-B", 0x26: "DN1-1F-AQ", 0x27: "DN1-1F-BQ",
    0x28: "DN1-LF-A", 0x29: "DN1-LF-B", 0x2A: "DN1-LF-AQ", 0x2B: "DN1-LF-BQ",
    0x2C: "DN1-AR-A", 0x2D: "DN1-AR-B", 0x2E: "DN1-AR-AQ", 0x2F: "DN1-AR-BQ",
    0x30: "UP1-0F-A", 0x31: "UP1-0F-B", 0x32: "UP1-0F-AQ", 0x33: "UP1-0F-BQ",
    0x34: "UP1-1F-A", 0x35: "UP1-1F-B", 0x36: "UP1-1F-AQ", 0x37: "UP1-1F-BQ",
    0x38: "UP1-LF-A", 0x39: "UP1-LF-B", 0x3A: "UP1-LF-AQ", 0x3B: "UP1-LF-BQ",
    0x3C: "ZERO", 0x3D: "SIGN", 0x3E: "OR", 0x3F: "XOR", 0x40: "AND",
    0x41: "XNOR", 0x42: "ADD", 0x43: "ADDC", 0x44: "SUB", 0x45: "SUBC",
    0x46: "SUBR", 0x47: "SUBRC", 0x48: "SUM-CORR-A", 0x49: "SUM-CORR-B",
    0x4A: "DIFF-CORR-A", 0x4B: "DIFF-CORR-B",
    0x4E: "SDIVFIRST", 0x4F: "UDIVFIRST", 0x50: "SDIVSTEP", 0x51: "SDIVLAST1",
    0x52: "MPDIVSTEP1", 0x53: "MPSDIVSTEP3", 0x54: "UDIVSTEP", 0x55: "UDIVLAST",
    0x56: "MPDIVSTEP2", 0x57: "MPUDIVSTP3", 0x58: "REMCORR", 0x59: "QUOCORR",
    0x5A: "SDIVLAST2", 0x5B: "UMULFIRST", 0x5C: "UMULSTEP", 0x5D: "UMULLAST",
    0x5E: "SMULSTEP", 0x5F: "SMULFIRST",
    0x60: "NB-SN-SHA", 0x61: "NB-SN-SHB", 0x62: "NB-0F-SHA", 0x63: "NB-0F-SHB",
    0x64: "NBROT-A", 0x65: "NBROT-B", 0x66: "EXTBIT-A", 0x67: "EXTBIT-B",
    0x68: "SETBIT-A", 0x69: "SETBIT-B", 0x6A: "RSTBIT-A", 0x6B: "RSTBIT-B",
    0x6C: "SETBIT-STAT", 0x6D: "RSTBIT-STAT", 0x6E: "NOTF-AL-B",
    0x6F: "PASSF-AL-B", 0x70: "NOTF-A", 0x71: "NOTF-AL-A", 0x72: "PASSF-A",
    0x73: "PASSF-AL-A", 0x74: "ORF-A", 0x75: "ORF-AL-A", 0x76: "XORF-A",
    0x77: "XORF-AL-A", 0x78: "ANDF-A", 0x79: "ANDF-AL-A", 0x7A: "EXTF-A",
    0x7B: "EXTF-B", 0x7C: "EXTF-AB", 0x7D: "EXTF-BA", 0x7E: "EXTBIT-STAT",
    0x7F: "PASS-MASK",
}
DEFINED = set(OPNAMES)
BYTEWID = {0: 4, 1: 1, 2: 2, 3: 3}
A_SRC = set(range(0x20, 0x40, 2)) | {0x00, 0x02, 0x06, 0x08, 0x0A, 0x0C,
                                     0x0E, 0x12, 0x16, 0x1A, 0x1C, 0x48,
                                     0x4A, 0x60, 0x62, 0x64, 0x66, 0x68,
                                     0x6A, 0x71, 0x73, 0x78, 0x7A, 0x7C}


def selmask(bw):
    return M32 if bw == 4 else (1 << (8 * bw)) - 1


def sext(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def rotl(x, n, bits=32):
    n %= bits
    m = (1 << bits) - 1
    if n == 0:
        return x & m
    return ((x << n) | (x >> (bits - n))) & m


def rotr(x, n, bits=32):
    return rotl(x, bits - (n % bits), bits)


def field_mask(p, w):
    """Contiguous field mask from bit p; w==0 -> [p,31]; truncate at bit 31."""
    if w == 0:
        w = 32 - p
    w = min(w, 32 - p)
    if w <= 0:
        return 0
    return ((1 << w) - 1) << p


def nib(v, i):
    return (v >> (4 * i)) & 0xF


def nib_carries_add(a, b, cin):
    """BCD nibble carries over the full 32-bit add (Appendix A rules 1 and 2)."""
    nc = [0] * 8
    bcout = [0] * 8
    c = cin & 1
    for i in range(8):
        s = nib(a, i) + nib(b, i) + c
        bcout[i] = 1 if s > 15 else 0
        if s > 9 or (s == 9 and i > 0 and nc[i - 1] == 1 and bcout[i - 1] == 0):
            nc[i] = 1
        c = bcout[i]
    return nc


def nib_borrows_sub(a, b, cin):
    """Nibble borrows = complement of the binary inter-nibble carries of a-b."""
    nc = []
    c = cin & 1
    for i in range(8):
        s = nib(a, i) + ((~nib(b, i)) & 0xF) + c
        c = 1 if s > 15 else 0
        nc.append(1 - c)
    return nc


def wadd(x, y2, cin, w):
    """w-bit add; returns (sum, carry_out, carry_into_msb)."""
    m = (1 << w) - 1
    t = (x & m) + (y2 & m) + (cin & 1)
    s = t & m
    cout = (t >> w) & 1
    lo = (x & (m >> 1)) + (y2 & (m >> 1)) + (cin & 1)
    return s, cout, (lo >> (w - 1)) & 1


def parity32(y):
    py = 0
    for i in range(4):
        py |= bin((y >> (8 * i)) & 0xFF).count("1") % 2 << i
    return py


class Model:
    """Lockstep Am29332 model: combinational outputs + next state per cycle."""

    def __init__(self):
        self.status = 0
        self.q = 0

    @staticmethod
    def stat_comb(status, borow):
        """Read-only relational bits are combinational functions of the
        stored flags (bit 13 also of the current BOROW pin): the register
        cells do not exist (EXTBIT-STAT note 2, PASS-STAT note 1)."""
        c = (status >> 16) & 1
        z = (status >> 19) & 1
        n = (status >> 17) & 1
        v = (status >> 18) & 1
        s13 = ((1 - c) if borow else c) | z
        s14 = n ^ v
        s15 = s14 | z
        comb = status & ~(0x0000_E000 | 0x0080_0000) & M32
        comb |= (s13 << 13) | (s14 << 14) | (s15 << 15)
        return comb

    def step(self, inp):
        op = inp["instr"] & 0x7F
        i87 = (inp["instr"] >> 7) & 3
        a, b = inp["da"], inp["db"]
        p, wp = inp["p"] & 0x3F, inp["w"] & 0x1F
        borow, macro = inp["borow"], inp["macro"]
        cin_sel = inp["mcin"] if macro else (self.status >> 16) & 1
        link_sel = inp["mlink"] if macro else (self.status >> 20) & 1
        status, q = self.status, self.q
        c0 = (status >> 16) & 1
        z0 = (status >> 19) & 1
        n0 = (status >> 17) & 1
        v0 = (status >> 18) & 1
        l0 = (status >> 20) & 1
        m0 = (status >> 21) & 1
        s0 = (status >> 22) & 1

        bw = BYTEWID[i87]
        sel = selmask(bw)
        w = 8 * bw
        upd = {"C": False, "Z": False, "N": False, "V": False,
               "L": False, "M": False, "S": False}
        nc_wrote = False  # only the add/subtract-class writes byte 3
        F = {"C": c0, "Z": z0, "N": n0, "V": v0, "L": l0, "M": m0, "S": s0}
        nc_packed = status & 0xFF00_0000  # nibble-carry byte, default unchanged
        q_next = q
        stat_write = None  # ("ldstat", wen, src) | ("prior", val) | ("bit", i, v)
        yv = b

        def setf(**kw):
            for k, val in kw.items():
                F[k] = val
                upd[k] = True

        def done(y):
            return y & M32

        if op not in DEFINED:
            yv = b  # unspecified opcodes: pass B, change nothing (ledger)

        elif op in (0x00, 0x01):  # ZERO-EXTA/B
            src = a if op == 0x00 else b
            yv = src
            setf(Z=int(yv == 0), N=(src >> (w - 1)) & 1)
        elif op in (0x02, 0x03):  # SIGN-EXTA/B
            src = a if op == 0x02 else b
            fill = M32 if (src >> (w - 1)) & 1 else 0
            yv = (src & sel) | (fill & ~sel)
            setf(Z=int(yv == 0), N=(src >> (w - 1)) & 1)
        elif op == 0x04:  # PASS-STAT
            yv = (Model.stat_comb(status, borow) & sel) | (b & ~sel)
        elif op == 0x05:  # PASS-Q
            yv = (q & sel) | (b & ~sel)
        elif op in (0x06, 0x07):  # LOADQ-A/B
            src = a if op == 0x06 else b
            q_next = (q & ~sel) | (src & sel)
            yv = (src & sel) | (q & ~sel)
            setf(Z=int((src & sel) == 0), N=(src >> (w - 1)) & 1)
        elif op in (0x08, 0x09):  # NOT-A/B
            src = a if op == 0x08 else b
            yv = (src & ~sel) | ((~src) & sel)
            setf(Z=int((yv & sel) == 0), N=(yv >> (w - 1)) & 1)
        elif op in (0x0A, 0x0B):  # NEG-A/B (subtract class: 0 - src)
            src = a if op == 0x0A else b
            s32, _, _ = wadd(0, (~src) & M32, 1, 32)
            s_w, cout_w, cin_msb = wadd(0, (~src) & M32, 1, w)
            nc = nib_borrows_sub(0, src, 1)
            yv = (src & ~sel) | (s32 & sel)
            setf(C=cout_w ^ borow, Z=int((yv & sel) == 0),
                 N=(yv >> (w - 1)) & 1, V=cin_msb ^ cout_w)
            nc_packed = sum(bit << (24 + i) for i, bit in enumerate(nc))
            nc_wrote = True
        elif op in (0x0C, 0x0D):  # PRIOR-A/B
            src = a if op == 0x0C else b
            f = src & sel
            val = (w - 1 - (f.bit_length() - 1)) if f else 0
            stat_write = ("prior", val)
            yv = val
            setf(Z=int(f == 0))
        elif op in (0x0E, 0x0F):  # MERGEA-B / MERGEB-A
            lo = a if op == 0x0E else b
            hi = b if op == 0x0E else a
            yv = (hi & ~sel) | (lo & sel)
            setf(Z=int((lo & sel) == 0), N=(lo >> (w - 1)) & 1)
        elif op in (0x10, 0x11, 0x14, 0x15, 0x18, 0x19):  # DECR class
            k = {0x10: 1, 0x11: 1, 0x14: 2, 0x15: 2, 0x18: 4, 0x19: 4}[op]
            src = a if op in (0x10, 0x14, 0x18) else b
            s32, _, _ = wadd(src, (~k) & M32, 1, 32)
            s_w, cout_w, cin_msb = wadd(src, (~k) & M32, 1, w)
            nc = nib_borrows_sub(src, k, 1)
            yv = (src & ~sel) | (s32 & sel)
            setf(C=cout_w ^ borow, Z=int((yv & sel) == 0),
                 N=(yv >> (w - 1)) & 1, V=cin_msb ^ cout_w)
            nc_packed = sum(bit << (24 + i) for i, bit in enumerate(nc))
            nc_wrote = True
        elif op in (0x12, 0x13, 0x16, 0x17, 0x1A, 0x1B):  # INCR class
            k = {0x12: 1, 0x13: 1, 0x16: 2, 0x17: 2, 0x1A: 4, 0x1B: 4}[op]
            src = a if op in (0x12, 0x16, 0x1A) else b
            s32, _, _ = wadd(src, k, 0, 32)
            s_w, cout_w, cin_msb = wadd(src, k, 0, w)
            nc = nib_carries_add(src, k, 0)
            yv = (src & ~sel) | (s32 & sel)
            setf(C=cout_w, Z=int((yv & sel) == 0),
                 N=(yv >> (w - 1)) & 1, V=cin_msb ^ cout_w)
            nc_packed = sum(bit << (24 + i) for i, bit in enumerate(nc))
            nc_wrote = True
        elif op in (0x1C, 0x1D):  # LDSTAT-A/B
            src = a if op == 0x1C else b
            stat_write = ("ldstat", sel, src)
            yv = (Model.stat_comb(status, borow) & ~sel) | (src & sel)
        elif 0x20 <= op <= 0x2F or 0x30 <= op <= 0x3B:  # single-bit shifts
            src = a if op in A_SRC else b
            double = op in (0x22, 0x23, 0x26, 0x27, 0x2A, 0x2B, 0x2E, 0x2F,
                            0x32, 0x33, 0x36, 0x37, 0x3A, 0x3B)
            up = op >= 0x30
            src_sel = src & sel
            q_sel = q & sel
            sgn = (src_sel >> (w - 1)) & 1
            qsign = (q_sel >> (w - 1)) & 1
            if not up:
                if op in (0x20, 0x21, 0x22, 0x23):
                    fill = 0
                elif op in (0x24, 0x25, 0x26, 0x27):
                    fill = 1
                elif op in (0x28, 0x29, 0x2A, 0x2B):
                    fill = link_sel
                else:
                    fill = sgn
                y_sel = (src_sel >> 1) | (fill << (w - 1))
                if double:
                    q_next = (q & ~sel) | ((q_sel >> 1) | ((src_sel & 1) << (w - 1)))
                    F["L"], upd["L"] = q_sel & 1, True
                else:
                    F["L"], upd["L"] = src_sel & 1, True
            else:
                if op in (0x30, 0x31, 0x32, 0x33):
                    fill = 0
                elif op in (0x34, 0x35, 0x36, 0x37):
                    fill = 1
                else:
                    fill = link_sel
                y_sel = ((src_sel << 1) & sel) | fill
                if double:
                    q_next = (q & ~sel) | (((q_sel << 1) & sel) | fill)
                F["L"], upd["L"] = sgn, True
                setf(V=sgn ^ ((y_sel >> (w - 1)) & 1))
            yv = (src & ~sel) | y_sel
            setf(N=(yv >> (w - 1)) & 1, Z=int((yv & sel) == 0))
        elif op == 0x3C:  # ZERO
            yv = b & ~sel
            setf(Z=1, N=0)
        elif op == 0x3D:  # SIGN
            fill = M32 if n0 else 0
            yv = (b & ~sel) | (fill & sel)
            setf(Z=int(n0 == 0))
        elif op in (0x3E, 0x3F, 0x40, 0x41):  # OR XOR AND XNOR
            fn = {0x3E: lambda: a | b, 0x3F: lambda: a ^ b,
                  0x40: lambda: a & b, 0x41: lambda: (~(a ^ b)) & M32}[op]()
            yv = (b & ~sel) | (fn & sel)
            setf(Z=int((yv & sel) == 0), N=(yv >> (w - 1)) & 1)
        elif op in (0x42, 0x43, 0x44, 0x45, 0x46, 0x47):  # ADD family
            subtract = op >= 0x44
            if subtract:
                cin = 1 if op in (0x44, 0x46) else (cin_sel ^ borow)
                x, y2 = (a, b) if op in (0x44, 0x45) else (b, a)
                s32, _, _ = wadd(x, (~y2) & M32, cin, 32)
                s_w, cout_w, cin_msb = wadd(x, (~y2) & M32, cin, w)
                nc = nib_borrows_sub(x, y2, cin)
            else:
                cin = 0 if op == 0x42 else cin_sel
                s32, _, _ = wadd(a, b, cin, 32)
                s_w, cout_w, cin_msb = wadd(a, b, cin, w)
                nc = nib_carries_add(a, b, cin)
            yv = (b & ~sel) | (s32 & sel)
            cflag = cout_w ^ borow if subtract else cout_w
            setf(C=cflag, Z=int((yv & sel) == 0),
                 N=(yv >> (w - 1)) & 1, V=cin_msb ^ cout_w)
            nc_packed = sum(bit << (24 + i) for i, bit in enumerate(nc))
            nc_wrote = True
        elif op in (0x48, 0x49, 0x4A, 0x4B):  # SUM/DIFF-CORR
            src = a if op in (0x48, 0x4A) else b
            diff = op >= 0x4A
            corr = 0
            ncs = [(status >> (24 + i)) & 1 for i in range(8)]
            for i in range(8):
                if ncs[i]:
                    corr |= 6 << (4 * i)
            if diff:
                s32, _, _ = wadd(src, (~corr) & M32, 1, 32)
            else:
                s32, _, _ = wadd(src, corr, 0, 32)
            msb_n = 2 * bw - 1
            yv = (src & ~sel) | (s32 & sel)
            if diff:
                cflag = 1 - (ncs[msb_n] ^ borow)
            else:
                cflag = ncs[msb_n]
            setf(C=cflag, Z=int((yv & sel) == 0),
                 N=(yv >> (w - 1)) & 1, V=ncs[msb_n] ^ ncs[msb_n - 1])
        elif op in (0x4E, 0x4F, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56,
                    0x57, 0x58, 0x59, 0x5A):  # divide family
            a_sel, b_sel = a & sel, b & sel
            q_sel = q & sel
            qsign = (q_sel >> (w - 1)) & 1
            asel_hi = (a_sel >> (w - 1)) & 1
            if op == 0x4F:  # UDIVFIRST
                yv = (b & ~sel) | (((b_sel << 1) & sel) | qsign)
                setf(L=(b_sel >> (w - 1)) & 1)
                q_next = (q & ~sel) | ((q_sel << 1) & sel)
                setf(M=1, S=0, N=(yv >> (w - 1)) & 1, Z=int((yv & sel) == 0))
            elif op == 0x4E:  # SDIVFIRST
                bsign = (b_sel >> (w - 1)) & 1
                qbit = 1 - (asel_hi ^ bsign)
                yv = (b & ~sel) | (((b_sel << 1) & sel) | qsign)
                setf(L=bsign, S=bsign)
                q_next = (q & ~sel) | (((q_sel << 1) & sel) | qbit)
                setf(M=qbit, N=(yv >> (w - 1)) & 1, Z=int((yv & sel) == 0))
            elif op == 0x54:  # UDIVSTEP
                bext = s0 << w | b_sel
                # subtract-with-carry complements the full (w+1)-bit
                # zero-extended A, so the extension bit contributes 1
                op2 = (((~a_sel) & sel) | (1 << w)) if m0 else a_sel
                f = bext + op2 + cin_sel
                f9 = f & ((1 << (w + 1)) - 1)
                cout9 = (f >> (w + 1)) & 1
                qbit = 1 - ((f9 >> w) & 1)
                rem_sign = (f9 >> (w - 1)) & 1
                yv = (b & ~sel) | (((f9 << 1) & sel) | qsign)
                setf(L=rem_sign, S=rem_sign)
                q_next = (q & ~sel) | (((q_sel << 1) & sel) | qbit)
                setf(M=qbit, C=cout9, N=(yv >> (w - 1)) & 1,
                     Z=int((yv & sel) == 0))
            elif op == 0x55:  # UDIVLAST
                bext = s0 << w | b_sel
                op2 = (((~a_sel) & sel) | (1 << w)) if m0 else a_sel
                f = bext + op2 + cin_sel
                f9 = f & ((1 << (w + 1)) - 1)
                cout9 = (f >> (w + 1)) & 1
                qbit = 1 - ((f9 >> w) & 1)
                yv = (b & ~sel) | (f9 & sel)
                q_next = (q & ~sel) | (((q_sel << 1) & sel) | qbit)
                setf(M=qbit, S=0, C=cout9, N=(f9 >> w) & 1,
                     Z=int((yv & sel) == 0))
            elif op == 0x50:  # SDIVSTEP
                op2 = ((~a_sel) & sel) if m0 else a_sel
                f, cout_w, _ = wadd(b_sel, op2, 1 if m0 else 0, w)
                rem_sign = (f >> (w - 1)) & 1
                qbit = 1 - (asel_hi ^ rem_sign)
                yv = (b & ~sel) | (((f << 1) & sel) | qsign)
                setf(L=rem_sign)
                q_next = (q & ~sel) | (((q_sel << 1) & sel) | qbit)
                setf(M=qbit, C=cout_w, N=(yv >> (w - 1)) & 1,
                     Z=int((yv & sel) == 0))
            elif op == 0x51:  # SDIVLAST1
                op2 = ((~a_sel) & sel) if m0 else a_sel
                f, cout_w, _ = wadd(b_sel, op2, 1 if m0 else 0, w)
                rem_sign = (f >> (w - 1)) & 1
                qbit = 1 - (asel_hi ^ rem_sign)
                yv = (b & ~sel) | f
                q_next = (q & ~sel) | (((q_sel << 1) & sel) | 1)
                setf(M=qbit, C=cout_w, N=rem_sign, Z=int((yv & sel) == 0))
            elif op == 0x5A:  # SDIVLAST2
                divsign = qsign
                op2 = ((~a_sel) & sel) if divsign else a_sel
                f, _, _ = wadd(b_sel, op2, 1 if divsign else 0, w)
                yv = (b & ~sel) | f
                setf(Z=(1 if f == 0 else 0) if s0 else 0)
            elif op == 0x52:  # MPDIVSTEP1
                op2 = ((~a) & M32) if m0 else a
                f, cout32, _ = wadd(b, op2, 1 if m0 else 0, 32)
                yv = ((f << 1) & M32) | qsign
                q_next = (q & ~sel) | ((q_sel << 1) & sel)
                setf(L=(f >> 31) & 1, C=cout32, Z=int((yv & sel) == 0))
            elif op == 0x56:  # MPDIVSTEP2
                op2 = ((~a) & M32) if m0 else a
                f, cout32, _ = wadd(b, op2, cin_sel, 32)
                yv = ((f << 1) & M32) | l0
                setf(L=(f >> 31) & 1, C=cout32, Z=int((yv & sel) == 0))
            elif op == 0x53:  # MPSDIVSTEP3
                op2 = ((~a_sel) & sel) if m0 else a_sel
                f, cout_w, _ = wadd(b_sel, op2, cin_sel, w)
                rem_sign = (f >> (w - 1)) & 1
                qbit = 1 - (asel_hi ^ rem_sign)
                yv = (b & ~sel) | (((f << 1) & sel) | l0)
                setf(L=rem_sign)
                q_next = (q & ~1) | qbit
                setf(M=qbit, C=cout_w, Z=int((yv & sel) == 0))
            elif op == 0x57:  # MPUDIVSTP3
                bext = s0 << w | b_sel
                op2 = (((~a_sel) & sel) | (1 << w)) if m0 else a_sel
                f = bext + op2 + cin_sel
                f9 = f & ((1 << (w + 1)) - 1)
                cout9 = (f >> (w + 1)) & 1
                qbit = m0 ^ s0 ^ cout9
                rem_sign = (f9 >> (w - 1)) & 1
                yv = (b & ~sel) | (((f9 << 1) & sel) | l0)
                setf(L=rem_sign, S=rem_sign)
                q_next = (q & ~1) | qbit
                setf(M=qbit, C=cout9, Z=int((yv & sel) == 0))
            elif op == 0x58:  # REMCORR: remainder correction
                # Gate Z^N^S (ch2 literal; Z covers the SDIVLAST2 special
                # case, N^S the sign-difference case; verified against true
                # truncating division at all widths)
                cond = z0 ^ n0 ^ s0
                if cond:
                    op2 = ((~a_sel) & sel) if m0 else a_sel
                    f, cout_w, _ = wadd(b_sel, op2, 1 if m0 else 0, w)
                else:
                    f, cout_w = b_sel & sel, 0
                yv = (b & ~sel) | f
                setf(C=cout_w)
            else:  # 0x59 QUOCORR
                cond = z0 ^ n0 ^ s0
                if cond:
                    op2 = 1 if m0 else ((~1) & sel)
                    f, cout_w, cin_msb = wadd(b_sel, op2, 0 if m0 else 1, w)
                else:
                    f, cout_w, cin_msb = b_sel & sel, 0, 0
                yv = (b & ~sel) | f
                setf(C=cout_w, V=cin_msb ^ cout_w)
        elif op in (0x5B, 0x5F, 0x5C, 0x5E, 0x5D):  # multiply family
            first = op in (0x5B, 0x5F)
            signed = op in (0x5F, 0x5E)
            ext = (1 << (w + 2)) - 1
            a_sel, b_sel = a & sel, b & sel
            q_sel = q & sel
            q1, q0 = (q_sel >> 1) & 1, q_sel & 1
            if first:
                astar = (sext(a_sel, w) & ext) if signed else a_sel
                fstar = {(0, 0): 0, (0, 1): astar,
                         (1, 0): (-2 * astar) & ext,
                         (1, 1): (-astar) & ext}[(q1, q0)]
            elif op == 0x5D:  # UMULLAST
                f = ((b_sel + a_sel) & sel) if m0 else b_sel
                yv = (b & ~sel) | f
                setf(Z=int((yv & sel) == 0))
                q_next = q
            else:
                astar = (sext(a_sel, w) & ext) if signed else (a_sel & ext)
                bstar = sext(b_sel, w) & ext
                code = (q1 << 2) | (q0 << 1) | m0
                fstar = {0b000: bstar, 0b111: bstar,
                         0b001: bstar + astar, 0b010: bstar + astar,
                         0b101: bstar - astar, 0b110: bstar - astar,
                         0b011: bstar + 2 * astar,
                         0b100: bstar - 2 * astar}[code] & ext
            if op != 0x5D:
                fstar &= ext
                yv = (b & ~sel) | ((fstar >> 2) & sel)
                q_next = (q & ~sel) | ((((q_sel >> 2) | ((fstar & 3) << (w - 2))) & sel))
                setf(M=q1)
        elif 0x60 <= op <= 0x65:  # N-bit shifts / rotates
            src = a if op in A_SRC or op in (0x60, 0x62, 0x64) else b
            psel, wsel = i87 >> 1, i87 & 1
            p6 = ((status & 0x3F) if psel else p) & 0x3F
            pv = sext(p6, 6)
            if op in (0x60, 0x61):  # NB-SN
                if pv >= 0:
                    yv = (src << pv) & M32
                else:
                    sh = min(-pv, 32)
                    fill = M32 if (src >> 31) & 1 else 0
                    if sh == 32:
                        yv = fill
                    else:
                        yv = ((src >> sh) | (fill << (32 - sh))) & M32
            elif op in (0x62, 0x63):  # NB-0F
                if pv >= 0:
                    yv = (src << pv) & M32
                else:
                    sh = min(-pv, 32)
                    yv = (src >> sh) & M32 if sh < 32 else 0
            else:  # NBROT
                yv = rotl(src, p6 & 0x1F)
            setf(N=(yv >> 31) & 1, Z=int(yv == 0))
        elif 0x66 <= op <= 0x6D or op == 0x7E:  # bit manipulation
            psel = i87 >> 1
            p6 = ((status & 0x3F) if psel else p) & 0x3F
            pu, psign = p6 & 0x1F, (p6 >> 5) & 1
            if op in (0x66, 0x67):  # EXTBIT
                src = a if op == 0x66 else b
                bit = ((src >> pu) & 1) ^ psign
                yv = bit
                setf(L=bit, Z=int(yv == 0))
            elif op in (0x68, 0x69):  # SETBIT
                src = a if op == 0x68 else b
                yv = src | (1 << pu)
                setf(Z=0, N=(yv >> 31) & 1)
            elif op in (0x6A, 0x6B):  # RSTBIT
                src = a if op == 0x6A else b
                yv = src & ~(1 << pu) & M32
                setf(Z=1, N=(yv >> 31) & 1)
            elif op in (0x6C, 0x6D):  # SETBIT/RSTBIT-STAT
                newstat = Model._apply_stat_bit(status, pu, 1 if op == 0x6C else 0)
                stat_write = ("replace", newstat)
                yv = Model.stat_comb(newstat, borow)
            else:  # 0x7E EXTBIT-STAT
                bit = ((Model.stat_comb(status, borow) >> pu) & 1) ^ psign
                yv = bit
                setf(L=bit, Z=int(yv == 0))
        elif 0x6E <= op <= 0x7D or op == 0x7F:  # field logical + mask
            psel, wsel = i87 >> 1, i87 & 1
            p6 = ((status & 0x3F) if psel else p) & 0x3F
            w5 = ((status >> 8) & 0x1F) if wsel else wp
            pv = sext(p6, 6)
            pu, psign = p6 & 0x1F, (p6 >> 5) & 1
            if op == 0x7F:  # PASS-MASK
                yv = field_mask(pu, w5) ^ (M32 if psign else 0)
            elif op in (0x7A, 0x7B):  # EXTF-A/B
                src = a if op == 0x7A else b
                if pv >= 0:
                    yv = ((src << pv) & field_mask(pv, w5)) & M32
                else:
                    yv = rotr(src, -pv) & field_mask(0, w5)
                setf(N=(yv >> 31) & 1, Z=int(yv == 0))
            elif op in (0x7C, 0x7D):  # EXTF-AB / EXTF-BA
                hi, lo = (a, b) if op == 0x7C else (b, a)
                cat = (hi << 32) | lo
                r64 = rotl(cat, pv, 64) if pv >= 0 else rotr(cat, -pv, 64)
                m = field_mask(0, w5) & M32
                yv = r64 & m
                setf(N=(yv >> 31) & 1, Z=int(yv == 0))
            else:
                aligned = op in (0x6E, 0x6F, 0x71, 0x73, 0x75, 0x77, 0x79)
                if aligned:
                    m = field_mask(pu, w5)
                    f = {0x6E: (~b) & m, 0x6F: b & m,
                         0x71: (~a) & m, 0x73: a & m,
                         0x75: (a | b) & m, 0x77: (a ^ b) & m,
                         0x79: (a & b) & m}[op]
                    yv = (b & ~m) | f
                else:
                    m = field_mask(0, w5) if pv < 0 else field_mask(pv, w5)
                    src2 = (a << pv) & M32 if pv >= 0 else rotr(a, -pv)
                    f = {0x70: (~src2) & m, 0x72: src2 & m,
                         0x74: (src2 | b) & m, 0x76: (src2 ^ b) & m,
                         0x78: (src2 & b) & m}[op]
                    yv = (b & ~m) | f
                setf(N=(yv >> 31) & 1, Z=int(f == 0))
        else:
            raise AssertionError(f"unhandled opcode {op:#x}")

        yv &= M32
        # ---------------- status register next value ----------------------
        status_next = status
        if stat_write is not None:
            kind = stat_write[0]
            if kind == "ldstat":
                _, wen, src = stat_write
                status_next = (status & ~wen & M32) | (src & wen)
            elif kind == "prior":
                status_next = (status & ~0xFF) | (stat_write[1] & 0x1F)
            elif kind == "replace":
                status_next = stat_write[1]
        # flag byte (16..22): keep flags that were not updated
        fb_new = ((F["C"] & 1) << 16) | ((F["N"] & 1) << 17) | ((F["V"] & 1) << 18) \
                 | ((F["Z"] & 1) << 19) | ((F["L"] & 1) << 20) | ((F["M"] & 1) << 21) \
                 | ((F["S"] & 1) << 22)
        keep = 0
        for bit, key in ((16, "C"), (17, "N"), (18, "V"), (19, "Z"),
                         (20, "L"), (21, "M"), (22, "S")):
            if not upd[key]:
                keep |= 1 << bit
        status_next = (status_next & ~0x00FF_0000 & M32) \
            | ((fb_new & ~keep & 0x00FF_0000) | (status_next & keep))
        # relational read-only bits (13..15) and bit 23: combinational
        # functions of the register's final flag byte and the current BOROW
        # (no storage cells; EXTBIT-STAT note 2)
        s13 = ((1 - (status_next >> 16 & 1)) if borow else (status_next >> 16 & 1)) \
            | (status_next >> 19 & 1)
        s14 = (status_next >> 17 & 1) ^ (status_next >> 18 & 1)
        s15 = s14 | (status_next >> 19 & 1)
        status_next = (status_next & ~0x0000_E000 & M32) \
            | (s13 << 13) | (s14 << 14) | (s15 << 15)
        status_next &= ~(1 << 23)
        status_next = (status_next & ~0xFF00_0000 & M32) \
            if nc_wrote else status_next
        if nc_wrote:
            status_next |= nc_packed & 0xFF00_0000
        status_next &= M32
        q_next &= M32

        if not inp["hold"]:
            self.status, self.q = status_next, q_next

        cznvl = (F["C"], F["Z"], F["N"], F["V"], F["L"])
        updm = (upd["C"], upd["Z"], upd["N"], upd["V"], upd["L"],
                upd["M"], upd["S"])
        return {
            "y": yv, "cznvl": cznvl, "updmask": updm,
            "py": parity32(yv), "perr": self.parity_error(inp),
            "status_next": status_next, "q_next": q_next,
            "status_muxed": self._flag_mux(inp, status, cznvl, updm),
        }

    # ---------------- sub-helpers -----------------------------------------
    def _flag_mux(self, inp, status, cznvl, updm):
        """C/Z/N/V/L pin values per the RS/HOLD select (master view)."""
        c, z, n, v, l = cznvl
        uc, uz, un, uv, ul = updm[:5]
        sc = (status >> 16) & 1
        sz = (status >> 19) & 1
        sn = (status >> 17) & 1
        sv = (status >> 18) & 1
        sl = (status >> 20) & 1
        if inp["rs"] or inp["hold"]:
            return (sc, sz, sn, sv, sl)
        return (c if uc else sc, z if uz else sz, n if un else sn,
                v if uv else sv, l if ul else sl)

    @staticmethod
    def _apply_stat_bit(status, pu, val):
        if pu in (13, 14, 15, 23):
            return status  # read-only bits
        if pu in (20, 21, 22, 16, 17, 18, 19):
            # flag bits are writable through SETBIT/RSTBIT-STAT (bits 16..22
            # are ordinary register bits; 13..15/23 read-only)
            pass
        return (status | (1 << pu)) if val else (status & ~(1 << pu) & M32)

    def parity_error(self, inp):
        err = 0
        for i in range(4):
            for bus, pp, sh in ((inp["da"], inp["pa"], 8 * i),
                                (inp["db"], inp["pb"], 8 * i)):
                byte = (bus >> sh) & 0xFF
                if (bin(byte).count("1") + ((pp >> i) & 1)) % 2:
                    err = 1
        return err


# ======================================================================
# Curated worked examples (transcribed from the manual). The manual's
# printed expected values live in check_worked_examples(); --check-table
# asserts them against the model above (the transcription guard).
# ======================================================================

def row(name, instr, **kw):
    d = dict(instr=instr, p=0, w=0, da=0, db=0, pa=0, pb=0, mcin=0, mlink=0,
             borow=0, macro=0, rs=0, hold=0, slave=0, oey_n=0)
    d.update(kw)
    d["name"] = name
    return d


INPUT_KEYS = ("instr", "p", "w", "da", "db", "pa", "pb", "mcin", "mlink",
              "borow", "macro", "rs", "hold", "slave", "oey_n")


def apply_row(model, d):
    """Step the model on row d; return (model out, expected TB checks)."""
    inp = {k: d[k] for k in INPUT_KEYS}
    out = model.step(inp)
    if inp["slave"]:
        driven_y = d.get("drv_y", 0)
        driven_py = d.get("drv_py", 0)
        driven_f = d.get("drv_f", 0)
        driven_pe = d.get("drv_pe", 0)
        cmp_active = not inp["oey_n"]
        mserr = 0
        if cmp_active and (driven_y != out["y"] or driven_py != out["py"]):
            mserr = 1
        if driven_f != out["status_muxed"]:
            mserr = 1
        if driven_pe != out["perr"]:
            mserr = 1
        exp = dict(y=driven_y, y_oe=0, py=driven_py,
                   cznvl=((driven_f >> 4) & 1, (driven_f >> 3) & 1,
                          (driven_f >> 2) & 1, (driven_f >> 1) & 1,
                          driven_f & 1),
                   perr=driven_pe, mserr=mserr)
    else:
        exp = dict(y=out["y"], y_oe=0 if inp["oey_n"] else 1, py=out["py"],
                   cznvl=out["status_muxed"], perr=out["perr"], mserr=0)
    return out, exp


def vector_line(d, exp, edge=1):
    vals = [d[k] for k in INPUT_KEYS]
    vals += [d.get("drv_y", 0), d.get("drv_py", 0), d.get("drv_f", 0),
             d.get("drv_pe", 0), edge,
             exp["y"], exp["y_oe"], exp["py"],
             (exp["cznvl"][0] << 4) | (exp["cznvl"][1] << 3)
             | (exp["cznvl"][2] << 2) | (exp["cznvl"][3] << 1)
             | exp["cznvl"][4],
             exp["perr"], exp["mserr"]]
    return " ".join(f"{v:x}" for v in vals)


def expand(model, rows):
    """Emit vector lines for rows plus PASS-STAT/PASS-Q readback windows."""
    lines = []
    for d in rows:
        out, exp = apply_row(model, d)
        lines.append(vector_line(d, exp, edge=1))
        if d.get("slave"):
            continue
        for opc in (0x04, 0x05):  # PASS-STAT / PASS-Q readback at bw=4
            rd = row(f"{d['name']} rb", opc)
            rout = model.step({k: rd[k] for k in INPUT_KEYS})
            rexp = dict(y=rout["y"], y_oe=1, py=rout["py"],
                        cznvl=rout["status_muxed"], perr=rout["perr"],
                        mserr=0)
            lines.append(vector_line(rd, rexp, edge=1))
    return lines


def appb_multiply_rows():
    """Appendix B trace: 65h x 48h, one byte, unsigned; product 1C68h."""
    return [
        row("appb-mul-1 LOADQ-A", 0x06 | (1 << 7), da=0x65),
        row("appb-mul-2 UMULFIRST", 0x5B | (1 << 7), da=0x48, db=0x00),
        row("appb-mul-3 UMULSTEP", 0x5C | (1 << 7), da=0x48, db=0x12),
        row("appb-mul-4 UMULSTEP", 0x5C | (1 << 7), da=0x48, db=0x16),
        row("appb-mul-5 UMULSTEP", 0x5C | (1 << 7), da=0x48, db=0xE1),
        row("appb-mul-6 UMULLAST", 0x5D | (1 << 7), da=0x48, db=0x1C),
        row("appb-mul-7 PASS-Q", 0x05 | (1 << 7)),
    ]


def appb_divide_rows():
    """Appendix B trace: 75h / 02h, one byte, unsigned; Q=3Ah rem 01h.

    Row 0 initializes the status register to C=1 (LDSTAT-A, byte width 4);
    the trace's first UDIVSTEP consumes carry-in 1 per the printed Y values.
    """
    return [
        row("appb-div-0 LDSTAT-A C=1", 0x1C, da=0x00010000),
        row("appb-div-1 LOADQ-A", 0x06 | (1 << 7), da=0x75),
        row("appb-div-2 UDIVFIRST", 0x4F | (1 << 7), da=0x02, db=0x00),
        row("appb-div-3 UDIVSTEP", 0x54 | (1 << 7), da=0x02, db=0x00),
        row("appb-div-4 UDIVSTEP", 0x54 | (1 << 7), da=0x02, db=0xFD),
        row("appb-div-5 UDIVSTEP", 0x54 | (1 << 7), da=0x02, db=0xFF),
        row("appb-div-6 UDIVSTEP", 0x54 | (1 << 7), da=0x02, db=0x03),
        row("appb-div-7 UDIVSTEP", 0x54 | (1 << 7), da=0x02, db=0x02),
        row("appb-div-8 UDIVSTEP", 0x54 | (1 << 7), da=0x02, db=0x01),
        row("appb-div-9 UDIVSTEP", 0x54 | (1 << 7), da=0x02, db=0xFE),
        row("appb-div-10 UDIVLAST", 0x55 | (1 << 7), da=0x02, db=0x01),
        row("appb-div-11 REMCORR", 0x58 | (1 << 7), da=0x02, db=0xFF),
        row("appb-div-12 PASS-Q", 0x05 | (1 << 7)),
    ]


def bcd_rows():
    """Appendix A examples 1-13 as add/subtract + correct pairs."""
    rows = []
    bw2 = 2 << 7
    # (operands, binary result fed back as the correction operand)
    for (x, y2, tag), binres in [
            ((0x0044, 0x0044, "1"), 0x0088), ((0x0045, 0x0045, "2"), 0x008A),
            ((0x0048, 0x0048, "3"), 0x0090), ((0x0048, 0x0058, "4"), 0x00A0),
            ((0x0045, 0x0045, "5"), 0x008A), ((0x0428, 0x0568, "6"), 0x0990),
            ((0x0428, 0x0578, "7"), 0x09A0)]:
        rows.append(row(f"appa-add-{tag}", 0x42 | bw2, da=x, db=y2))
        rows.append(row(f"appa-sumcorr-{tag}", 0x48 | bw2, da=binres, db=y2))
    for (x, y2, tag), binres in [
            ((0x0035, 0x0064, "8"), 0x009A), ((0x0037, 0x0068, "9"), 0x00A0),
            ((0x0037, 0x0058, "10"), 0x0090)]:
        rows.append(row(f"appa-addc-{tag}", 0x43 | bw2, da=x, db=y2,
                        macro=1, mcin=1))
        rows.append(row(f"appa-sumcorr-{tag}", 0x48 | bw2, da=binres, db=y2))
    bw1 = 1 << 7
    for (x, y2, tag), binres in [
            ((0x05, 0x03, "11"), 0x02), ((0x05, 0x05, "12"), 0x00),
            ((0x03, 0x05, "13"), 0xFE)]:
        rows.append(row(f"appa-sub-{tag}", 0x44 | bw1, da=x, db=y2))
        rows.append(row(f"appa-diffcorr-{tag}", 0x4A | bw1, da=binres, db=y2))
    return rows


def ch2_field_rows():
    """Chapter 2 worked examples; direct position/width pins (I8=I7=0)."""
    return [
        row("ch2-andf-a-p3w0", 0x78, p=3, w=0, da=0x7215180F, db=0x8FCE1372),
        row("ch2-andf-a-pneg4w0", 0x78, p=0x3C, w=0, da=0x71723FED, db=0x82CE1509),
        row("ch2-orf-a-p3w0", 0x74, p=3, w=0, da=0x7215180F, db=0x8FCE1372),
        row("ch2-orf-a-pneg4w0", 0x74, p=0x3C, w=0, da=0x71723FED, db=0x82CE1509),
        row("ch2-xorf-a-p3w0", 0x76, p=3, w=0, da=0x7215180F, db=0x8FCE1372),
        row("ch2-xorf-a-pneg4w0", 0x76, p=0x3C, w=0, da=0x71723FED, db=0x82CE1509),
        row("ch2-passf-a-p3w0", 0x72, p=3, w=0, da=0x72151805, db=0x8FCE1372),
        row("ch2-passf-a-pneg4w0", 0x72, p=0x3C, w=0, da=0x71723FED, db=0x82CE1509),
        row("ch2-notf-a-p2w0", 0x70, p=2, w=0, da=0x12345678, db=0x9ABCDEF2),
        row("ch2-notf-a-pneg2w0", 0x70, p=0x3E, w=0, da=0x12345678, db=0x9ABCDEF0),
        row("ch2-extf-a-p3w0", 0x7A, p=3, w=0, da=0x72151805),
        row("ch2-extf-a-pneg4w0", 0x7A, p=0x3C, w=0, da=0x71723FED),
        row("ch2-extf-b-p3w0", 0x7B, p=3, w=0, db=0x8FCE1372),
        row("ch2-extf-b-pneg4w0", 0x7B, p=0x3C, w=0, db=0x71723FED),
        row("ch2-prior-a", 0x0C | (3 << 7), da=0x4B228000),
    ]


def curated_rows():
    return (appb_multiply_rows() + appb_divide_rows() + bcd_rows()
            + ch2_field_rows())


# ======================================================================
# Algorithm sequences with independent (non-model) arithmetic assertions.
# ======================================================================

def build_sequences():
    rng = random.Random(29332)
    seqs = []
    for bw in (1, 2, 4):
        w = 8 * bw
        for _ in range(6):
            seqs.append(("umul", rng.randrange(1 << w), rng.randrange(1 << w),
                         bw, False))
            seqs.append(("smul", rng.randrange(1 << w), rng.randrange(1 << w),
                         bw, True))
        for _ in range(6):
            seqs.append(("udiv", rng.randrange(1 << w), rng.randrange(1, 1 << w),
                         bw, False))
            seqs.append(("sdiv", rng.randrange(1 << w), rng.randrange(1, 1 << w),
                         bw, True))
    return seqs


def sequence_rows(kind, x, y2, bw, signed):
    w = 8 * bw
    rows = []
    if kind in ("umul", "smul"):
        rows.append(row("s-loadq", 0x06 | (bw << 7), da=y2))
        rows.append(row("s-first", (0x5F if signed else 0x5B) | (bw << 7),
                        da=x, db=0))
        for _ in range(w // 2 - 1):
            rows.append(row("s-step", (0x5E if signed else 0x5C) | (bw << 7),
                            da=x))
        if not signed:
            rows.append(row("s-last", 0x5D | (bw << 7), da=x))
        rows.append(row("s-passq", 0x05 | (bw << 7)))
        return rows, ("mul", x, y2, signed, w)
    rows.append(row("d-loadq", 0x06 | (bw << 7), da=x))
    if kind == "udiv":
        # C=1 so the first subtract-with-carry is a clean REM-DIVS
        rows.append(row("d-initc", 0x1C, da=0x00010000))
        rows.append(row("d-first", 0x4F | (bw << 7), da=y2, db=0))
        for _ in range(w - 1):
            rows.append(row("d-step", 0x54 | (bw << 7), da=y2))
        rows.append(row("d-last", 0x55 | (bw << 7), da=y2))
        rows.append(row("d-remcorr", 0x58 | (bw << 7), da=y2))
    else:
        rem = M32 if (x >> (w - 1)) & 1 else 0
        rows.append(row("d-first", 0x4E | (bw << 7), da=y2, db=rem))
        for _ in range(w - 1):
            rows.append(row("d-step", 0x50 | (bw << 7), da=y2))
        rows.append(row("d-last1", 0x51 | (bw << 7), da=y2))
        rows.append(row("d-last2", 0x5A | (bw << 7), da=y2))
        rows.append(row("d-quocorr", 0x59 | (bw << 7), da=0))
        rows.append(row("d-remcorr", 0x58 | (bw << 7), da=y2))
    rows.append(row("d-passq", 0x05 | (bw << 7)))
    return rows, ("div", x, y2, signed, w)


def replay_sequence(rows, bw):
    """Replay resolving register feedback.

    The remainder register is written by FIRST, every STEP, LAST/LAST1 and
    REMCORR; SDIVLAST2 does not write it back ("the result is not expected
    to be used"); QUOCORR writes the quotient (read back over B for its own
    cycle).
    """
    mm = Model()
    resolved, y_of = [], {}
    rem_val = 0
    for d in rows:
        d2 = dict(d)
        nm = d2["name"]
        if nm.startswith(("s-step", "s-last", "d-step", "d-last1",
                          "d-last", "d-remcorr")) or nm == "d-last2":
            d2["db"] = rem_val
        if nm == "d-quocorr":
            d2["db"] = mm.q & selmask(bw)
        out = mm.step({k: d2[k] for k in INPUT_KEYS})
        y_of[nm] = out["y"]
        if nm in ("s-first", "s-step", "s-last", "d-step", "d-last",
                  "d-last1", "d-remcorr", "d-first"):
            rem_val = out["y"]
        resolved.append(d2)
    return resolved, mm, y_of


def verify_sequence(kind, x, y2, signed, w, mm, y_of):
    """Independent arithmetic oracle (never consults the model)."""
    sel = (1 << w) - 1
    if kind in ("umul", "smul"):
        prod = (sext(x, w) * sext(y2, w)) if signed else (x * y2)
        prod &= (1 << (2 * w)) - 1
        if (mm.q & sel) != (prod & sel):
            return f"product low: got {mm.q & sel:#x} want {prod & sel:#x}"
        hi_row = "s-last" if not signed else "s-step"
        if (y_of[hi_row] & sel) != ((prod >> w) & sel):
            return (f"product high: got {y_of[hi_row] & sel:#x} "
                    f"want {(prod >> w) & sel:#x}")
        return None
    if signed:
        sx, sy2 = sext(x, w), sext(y2, w)
        q_exp = abs(sx) // abs(sy2)
        if (sx < 0) != (sy2 < 0):
            q_exp = -q_exp
        r_exp = sx - q_exp * sy2
        q_exp &= sel
        r_exp &= sel
    else:
        q_exp, r_exp = x // y2, x % y2
    q_got = (y_of["d-quocorr"] if "d-quocorr" in y_of else mm.q) & sel
    if q_got != q_exp:
        return f"quotient: got {q_got:#x} want {q_exp:#x}"
    if (y_of["d-remcorr"] & sel) != r_exp:
        return f"remainder: got {y_of['d-remcorr'] & sel:#x} want {r_exp:#x}"
    return None


# ======================================================================
# Worked-example transcription guard (manual's printed values vs model).
# ======================================================================

def check_worked_examples():
    errs = []
    mul_expect = [0x65, 0x12, 0x16, 0xE1, 0x1C, 0x1C, 0x68]
    m = Model()
    for d, ywant in zip(appb_multiply_rows(), mul_expect):
        out = m.step({k: d[k] for k in INPUT_KEYS})
        if out["y"] & 0xFF != ywant & 0xFF:
            errs.append(f"{d['name']}: Y={out['y']:#x} want {ywant:#x}")
    if m.q & 0xFF != 0x68:
        errs.append(f"mul final Q={m.q & 0xFF:#x} want 0x68")
    div_expect = [0x00, 0x75, 0x00, 0xFD, 0xFF, 0x03, 0x02, 0x01, 0xFE, 0x01,
                  0xFF, 0x01, 0x3A]
    m = Model()
    for d, ywant in zip(appb_divide_rows(), div_expect):
        out = m.step({k: d[k] for k in INPUT_KEYS})
        if out["y"] & 0xFF != ywant & 0xFF:
            errs.append(f"{d['name']}: Y={out['y'] & 0xFF:#x} want {ywant:#x}")
    bcd_expect = {
        "appa-sumcorr-1": 0x088, "appa-sumcorr-2": 0x090,
        "appa-sumcorr-3": 0x096, "appa-sumcorr-4": 0x106,
        "appa-sumcorr-5": 0x090, "appa-sumcorr-6": 0x996,
        "appa-sumcorr-7": 0x1006, "appa-sumcorr-8": 0x100,
        "appa-sumcorr-9": 0x106, "appa-sumcorr-10": 0x096,
        "appa-diffcorr-11": 0x02, "appa-diffcorr-12": 0x00,
        "appa-diffcorr-13": 0x98,
    }
    m = Model()
    for d in bcd_rows():
        out = m.step({k: d[k] for k in INPUT_KEYS})
        want = bcd_expect.get(d["name"])
        if want is not None:
            sm = selmask(BYTEWID[(d["instr"] >> 7) & 3])
            if out["y"] & sm != want & sm:
                errs.append(f"{d['name']}: Y={out['y'] & sm:#x} want {want:#x}")
    nc_expect = {
        "appa-add-1": 0b0000, "appa-add-2": 0b0001, "appa-add-3": 0b0001,
        "appa-add-4": 0b0011, "appa-add-5": 0b0001, "appa-add-6": 0b0001,
        "appa-add-7": 0b0111, "appa-addc-8": 0b0011, "appa-addc-9": 0b0011,
        "appa-addc-10": 0b0001,
        "appa-sub-11": 0b00, "appa-sub-12": 0b00, "appa-sub-13": 0b11,
    }
    m = Model()
    for d in bcd_rows():
        out = m.step({k: d[k] for k in INPUT_KEYS})
        want = nc_expect.get(d["name"])
        if want is not None:
            got = out["status_next"] >> 24 & 0xFF
            # subtract-class nibble borrows above the selected width are
            # undefined (Appendix A); compare only the enabled nibbles
            nmask = (1 << 2 * BYTEWID[(d["instr"] >> 7) & 3]) - 1
            if got & nmask != want & nmask:
                errs.append(f"{d['name']}: NC={got & nmask:04b} "
                            f"want {want & nmask:04b}")
    ch2_expect = {
        # binary transcriptions win where the printed hex disagrees (OCR);
        # ch2-andf-a-pneg4w0's printed Y is garbled in the scan - the value
        # below is the model's, verified against the page image (page 30).
        "ch2-andf-a-p3w0": 0x80880072,
        "ch2-andf-a-pneg4w0": 0x82060108,
        "ch2-orf-a-p3w0": 0x9FEED37A,
        "ch2-orf-a-pneg4w0": 0xD7DF37FF,
        "ch2-xorf-a-p3w0": 0x1F66D30A,
        "ch2-xorf-a-pneg4w0": 0x55D936F7,
        "ch2-passf-a-p3w0": 0x90A8C02A,
        "ch2-passf-a-pneg4w0": 0xD71723FE,
        "ch2-notf-a-p2w0": 0xB72EA61E,
        "ch2-notf-a-pneg2w0": 0xFB72EA61,
        "ch2-extf-a-p3w0": 0x90A8C028,
        "ch2-extf-a-pneg4w0": 0xD71723FE,
        "ch2-extf-b-p3w0": 0x7E709B90,
        "ch2-extf-b-pneg4w0": 0xD71723FE,
        "ch2-prior-a": 2,
    }
    m = Model()
    for d in ch2_field_rows():
        out = m.step({k: d[k] for k in INPUT_KEYS})
        want = ch2_expect.get(d["name"])
        if want is not None and out["y"] != want:
            errs.append(f"{d['name']}: Y={out['y']:#x} want {want:#x}")
    return errs


def main():
    argv = sys.argv[1:]
    out_path = (ROOT / "work" / "sim" / "vectors.txt").resolve()
    mode = "write"
    if argv and argv[0] == "--check-table":
        mode = "check"
    if mode == "check":
        errs = check_worked_examples()
        if errs:
            for e in errs:
                print("CHECK FAIL:", e)
            sys.exit(1)
        print("check-table: all curated worked examples match the model")
        return
    seq_errors = []
    lines = []
    m = Model()
    lines += expand(m, curated_rows())
    for kind, x, y2, bw, signed in build_sequences():
        rows, meta = sequence_rows(kind, x, y2, bw, signed)
        resolved, mm, y_of = replay_sequence(rows, bw)
        err = verify_sequence(kind, x, y2, signed, 8 * bw, mm, y_of)
        if err:
            seq_errors.append(f"{kind} x={x:#x} y={y2:#x} bw={bw}: {err}")
        lines += expand(m, resolved)
    if seq_errors:
        for e in seq_errors:
            print("SEQUENCE FAIL:", e)
        sys.exit(1)
    rng = random.Random(0x29332)
    rand_rows = []
    for op in sorted(DEFINED):
        name = OPNAMES[op]
        fmt2 = op >= 0x60
        for i87 in range(4):
            for _ in range(6):
                d = row(f"rand-{name}-{i87}", op | (i87 << 7),
                        da=rng.getrandbits(32), db=rng.getrandbits(32),
                        pa=rng.getrandbits(4), pb=rng.getrandbits(4),
                        mcin=rng.getrandbits(1), mlink=rng.getrandbits(1),
                        borow=rng.getrandbits(1), macro=rng.getrandbits(1),
                        rs=rng.getrandbits(1), hold=rng.getrandbits(1))
                if fmt2:
                    d["p"] = rng.getrandbits(6)
                    d["w"] = rng.getrandbits(5)
                rand_rows.append(d)
                if rng.getrandbits(1):
                    h = dict(d)
                    h["name"] += "-hold"
                    h["hold"] = 1
                    rand_rows.append(h)
    lines += expand(m, rand_rows)
    slave_rows = []
    for op in (0x42, 0x44, 0x08, 0x3C, 0x04):
        for i87 in range(4):
            slave_rows.append(row(f"slave-{OPNAMES[op]}-{i87}",
                                  op | (i87 << 7),
                                  da=rng.getrandbits(32),
                                  db=rng.getrandbits(32),
                                  slave=1, drv_y=rng.getrandbits(32),
                                  drv_py=rng.getrandbits(4),
                                  drv_f=rng.getrandbits(5),
                                  drv_pe=rng.getrandbits(1)))
    pa_ok = sum((bin((0x12345678 >> (8 * i)) & 0xFF).count("1") % 2) << i
                for i in range(4))
    pb_ok = sum((bin((0x9ABCDEF0 >> (8 * i)) & 0xFF).count("1") % 2) << i
                for i in range(4))
    slave_rows.append(row("parity-ok", 0x42, da=0x12345678, db=0x9ABCDEF0,
                          pa=pa_ok, pb=pb_ok))
    slave_rows.append(row("parity-bad", 0x42, da=0x12345678, db=0x9ABCDEF0,
                          pa=pa_ok ^ 1, pb=pb_ok))
    lines += expand(m, slave_rows)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n")
    print(f"wrote {len(lines)} vectors to {out_path}")


if __name__ == "__main__":
    main()
