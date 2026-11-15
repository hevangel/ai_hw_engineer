#!/usr/bin/env python3
"""Reference model of the IBM Enhanced Graphics Adapter (256 KB).

Written from IBM's "IBM Enhanced Graphics Adapter" technical reference
(August 2, 1984; "TR p.N" = printed page) and the contract in
spec/spec.md, not from the RTL. Behaviour TR leaves open is tagged
"ASSUMPTION En" with the same tag as the spec ledger and the RTL.

Time model. A bench script advances time in master pulses ("T n": n clocks
in which both oscillator enables pulse). Every bus operation is atomic
between two pulses. The video output is one value per dot.

Command line (lockstep partner of tb/ega_tb.cpp):

    ega_model.py SCRIPT TRACE_OUT [--rom CPU_ORDER_BIN] [--coverage COV]

runs SCRIPT (format at the top of tb/ega_tb.cpp), writes the same trace the
bench writes, and checks every expectation in the script. Exit status 1 on
a failed expectation.
"""
import argparse
import json
import sys

# ---------------------------------------------------------------- helpers


def bit(v, n):
    return (v >> n) & 1


def ror8(v, n):
    n &= 7
    return ((v >> n) | (v << (8 - n))) & 0xFF


# register masks: only documented bits are stored (TR register formats)
SEQ_MASK = [0x03, 0x0F, 0x0F, 0x0F, 0x07]
GC_MASK = [0x0F, 0x0F, 0x0F, 0x1F, 0x07, 0x3F, 0x0F, 0x0F, 0xFF]
ATTR_MASK = {0x10: 0x0F, 0x11: 0x3F, 0x12: 0x3F, 0x13: 0x0F}


class Pipe:
    """One fetched character: what the CRTC flagged and memory returned."""
    __slots__ = ('de', 'blank', 'hs', 'vs', 'cursor', 'ul', 'hcodd',
                 'planes', 'font', 'gcgraph', 'ma')

    def __init__(self):
        self.de = self.blank = self.hs = self.vs = 0
        self.cursor = self.ul = self.hcodd = 0
        self.planes = [0, 0, 0, 0]
        self.font = 0
        self.gcgraph = 0
        self.ma = 0


class EGA:
    def __init__(self, rom=None):
        self.rom = rom if rom is not None else bytes(16384)
        self.cov = {}
        self.power_on()

    def c(self, k, n=1):
        self.cov[k] = self.cov.get(k, 0) + n

    # ------------------------------------------------------------ state
    def power_on(self):
        # ASSUMPTION E1: rst_n clears everything to 0.
        self.planes = [bytearray(65536) for _ in range(4)]
        self.misc = 0
        self.fcr = 0
        self.seq_idx = 0
        self.seq = [0] * 5
        self.crtc_idx = 0
        self.crtc = [0] * 25
        self.gc_idx = 0
        self.gc = [[0] * 9, [0] * 9]     # GC 1, GC 2 (both receive every write)
        self.gc_pos = [0, 0]
        self.attr_idx = 0
        self.attr_ff = 0
        self.pal = [0] * 16
        self.areg = {0x10: 0, 0x11: 0, 0x12: 0, 0x13: 0}
        self.latch = [0, 0, 0, 0]
        self.lpff = 0
        self.lp_prev = 0
        self.lp = 0
        self.intlatch = 0
        self.blink = 0
        # inputs
        self.reset_drv = 0
        self.sw = 0xF
        self.p1 = 1
        self.p3 = 1
        self.feat = 0
        self.lpen_n = 1
        self.lpsw_n = 1
        self.dack0_n = 1
        # CRTC counters
        self.hc = self.vc = self.rs = 0
        self.row_start = self.ma = 0
        self.hb = self.hs = self.vb = self.vsl = 0
        self.vdiv = 0
        # sequencer
        self.dotcnt = 0
        self.half = 0
        self.wchar = 9
        # pipeline: history of fetched characters, newest last
        self.hist = [Pipe() for _ in range(6)]
        self.cur_idx = [0] * 9
        self.nxt_idx = [0] * 9
        self.de_out = self.blank_out = self.hs_out = self.vs_out = 0
        self.last_color = 0
        # dot recording
        self.out = []          # list of dot values of the current T

    # ------------------------------------------------------- derived regs
    def r(self, i):
        return self.crtc[i]

    def ov(self, b):
        return bit(self.crtc[7], b)

    @property
    def HT(self):
        return self.crtc[0]

    @property
    def VT(self):
        return self.crtc[6] | (self.ov(0) << 8)

    @property
    def VDE(self):
        return self.crtc[0x12] | (self.ov(1) << 8)

    @property
    def VRS(self):
        return self.crtc[0x10] | (self.ov(2) << 8)

    @property
    def VBS(self):
        return self.crtc[0x15] | (self.ov(3) << 8)

    @property
    def LC(self):
        return self.crtc[0x18] | (self.ov(4) << 8)

    def running(self):
        return self.seq[0] == 3

    def wnew(self):
        return 8 if self.seq[1] & 1 else 9

    def ext(self):
        return bit(self.seq[4], 1)

    # ------------------------------------------------------------ decode
    def io_port(self, a):
        """Return the decoded port name or None (sheet 4, spec table)."""
        if self.aen:
            return None
        if not bit(a, 9):
            return None
        if bit(a, 8) != (1 if self.p3 else 0):     # P3: 3XX or 2XX
            return None
        lo = a & 0xFF                               # A15-A10 not decoded
        x = 0xD0 if self.misc & 1 else 0xB0         # MONO MONITOR (misc bit 0)
        fixed = {0xC0: 'attr', 0xC2: 'c2', 0xC4: 'seqa', 0xC5: 'seqd',
                 0xCA: 'gc2pos', 0xCC: 'gc1pos', 0xCE: 'gca', 0xCF: 'gcd'}
        if lo in fixed:
            return fixed[lo]
        rel = {0x4: 'crtca', 0x5: 'crtcd', 0xA: 'xa', 0xB: 'lpclr', 0xC: 'lpset'}
        if lo & 0xF0 == x and (lo & 0xF) in rel:
            return rel[lo & 0xF]
        return None

    aen = 0

    def io_write(self, a, d, aen=0):
        self.aen = aen
        p = self.io_port(a)
        self.aen = 0
        if p is None:
            self.c('io_write_undecoded')
            return
        self.c('io_w_' + p)
        if p == 'attr':
            self.attr_write(d)
        elif p == 'c2':
            if not self.reset_drv:
                self.misc = d
                self.c_bits('misc', d, 8)
                if not self.running():
                    pass
        elif p == 'seqa':
            self.seq_idx = d & 0x0F
        elif p == 'seqd':
            i = self.seq_idx
            if i < 5:
                v = d & SEQ_MASK[i]
                self.seq[i] = v
                self.c_bits('seq%d' % i, v, 8)
                if i == 0:
                    if v != 3:
                        # ASSUMPTION E6: halted sequencer clears the dot phase
                        self.dotcnt = 0
                        self.half = 0
                    if not v & 1:
                        self.seq[3] = 0      # TR p.23: async reset clears it
                if i == 3 and not self.seq[0] & 1:
                    self.seq[3] = 0
        elif p == 'gc1pos':
            self.gc_pos[0] = d & 3
            self.c('gc1pos_%d' % (d & 3))
        elif p == 'gc2pos':
            self.gc_pos[1] = d & 3
            self.c('gc2pos_%d' % (d & 3))
        elif p == 'gca':
            self.gc_idx = d & 0x0F
        elif p == 'gcd':
            i = self.gc_idx
            if i < 9:
                v = d & GC_MASK[i]
                self.gc[0][i] = v
                self.gc[1][i] = v
                self.c_bits('gc%d' % i, v, 8)
        elif p == 'crtca':
            self.crtc_idx = d & 0x1F
        elif p == 'crtcd':
            i = self.crtc_idx
            if i < 25:
                self.crtc[i] = d
                self.c_bits('crtc%02x' % i, d, 8)
                if i == 0x11 and not bit(d, 4):
                    self.intlatch = 0
        elif p == 'xa':
            if not self.reset_drv:
                self.fcr = d & 3
                self.c_bits('fcr', d & 3, 2)
        elif p == 'lpclr':
            self.lpff = 0
        elif p == 'lpset':
            self.lpff = 1

    def c_bits(self, name, v, n):
        self.c('w_' + name)
        for b in range(n):
            self.c('wb_%s_%d_%d' % (name, b, bit(v, b)))

    def attr_write(self, d):
        if self.attr_ff == 0:
            self.attr_idx = d & 0x3F
        else:
            i = self.attr_idx & 0x1F
            if i < 16:
                # ASSUMPTION E27: palette loads only while address bit 5 = 0
                if not self.attr_idx & 0x20:
                    self.pal[i] = d & 0x3F
                    self.c_bits('pal%x' % i, d & 0x3F, 6)
                else:
                    self.c('pal_write_ignored')
            elif i in ATTR_MASK:
                v = d & ATTR_MASK[i]
                self.areg[i] = v
                self.c_bits('attr%02x' % i, v, 8)
        self.attr_ff ^= 1

    def io_read(self, a, aen=0):
        self.aen = aen
        p = self.io_port(a)
        self.aen = 0
        if p == 'c2':
            self.c('io_r_isr0')
            k = (self.misc >> 2) & 3
            # ASSUMPTION E31: clock select k reads switch SW(4-k)
            s = bit(self.sw, 3 - k)
            self.c('sw_read_%d_%d' % (k, s))
            # ASSUMPTION E4 (bits 3-0 pulled up), E9 (bit 7 = latch)
            return 0x0F | (s << 4) | ((self.feat & 3) << 5) | (self.intlatch << 7)
        if p == 'xa':
            self.c('io_r_isr1')
            self.attr_ff = 0                       # TR p.56
            m = (self.areg[0x12] >> 4) & 3
            c = self.last_color
            # ASSUMPTION E11
            diag = {0: (bit(c, 2) << 1) | bit(c, 0),
                    1: (bit(c, 3) << 1) | bit(c, 1),
                    2: (bit(c, 5) << 1) | bit(c, 4),
                    3: 0}[m]
            self.c('diag_mux_%d' % m)
            # ASSUMPTION E10: bit 0 = 1 while display enable is off
            return (0xC0 | (diag << 4) | (self.vsl << 3) | (self.lpsw_n << 2)
                    | (self.lpff << 1) | (1 - self.de_out))
        if p == 'crtcd':
            i = self.crtc_idx
            self.c('io_r_crtc')
            if i in (0x0C, 0x0D, 0x0E, 0x0F):
                self.c('crtc_read_%02x' % i)
                return self.crtc[i]
            if i == 0x10:
                self.c('crtc_read_lp')
                return self.lp >> 8
            if i == 0x11:
                return self.lp & 0xFF
            self.c('crtc_read_wo')
            return 0xFF                            # ASSUMPTION E4
        if p is not None:
            self.c('io_read_writeonly')
        return None

    # ------------------------------------------------------- CPU memory
    def ram_offset(self, a):
        if not self.dack0_n:
            return None
        if not bit(self.misc, 1):
            return None
        m = (self.gc[0][6] >> 2) & 3
        if m == 0 and 0xA0000 <= a <= 0xBFFFF:
            return a - 0xA0000
        if m == 1 and 0xA0000 <= a <= 0xAFFFF:
            return a - 0xA0000
        if m == 2 and 0xB0000 <= a <= 0xB7FFF:
            return a - 0xB0000
        if m == 3 and 0xB8000 <= a <= 0xBFFFF:
            return a - 0xB8000
        return None

    def plane_addr(self, o):
        m = (self.gc[0][6] >> 2) & 3
        if bit(self.gc[0][6], 1):
            # ASSUMPTION E28: A0 replaced by A16 (128 KB map) or NOT page bit
            x = bit(o, 16) if m == 0 else 1 - bit(self.misc, 5)
            pa = (o & 0xFFFE) | x
            self.c('chain_%d' % m)
        else:
            pa = o & 0xFFFF
        if not self.ext():
            pa &= 0x3FFF
        return pa

    def mem_read(self, a):
        if not self.dack0_n:
            self.c('mem_dack0_blocked')
            return None
        if 0xC0000 <= a <= 0xC3FFF:
            self.c('rom_read')
            return self.rom[a & 0x3FFF]
        o = self.ram_offset(a)
        if o is None:
            return None
        pa = self.plane_addr(o)
        data = [self.planes[p][pa] for p in range(4)]
        res = None
        for i in range(2):
            g = self.gc[i]
            pos = self.gc_pos[i]
            mode = g[5]
            if bit(mode, 3):
                self.c('read_mode1')
                v = 0xFF
                for q in range(2):
                    n = 2 * pos + q
                    # ASSUMPTION E15: don't-care bit 1 = plane is compared
                    if n < 4 and bit(g[7], n):
                        ref = 0xFF if bit(g[2], n) else 0
                        v &= ~(data[2 * i + q] ^ ref) & 0xFF
                drv = v
            else:
                rms = g[4]
                plane = ((rms & 6) | (o & 1)) if bit(mode, 4) else rms
                self.c('read_mode0_rms%d_oe%d' % (rms, bit(mode, 4)))
                drv = data[2 * i + (plane & 1)] if (plane >> 1) == pos else None
            if drv is not None:
                res = drv if res is None else (res & drv)   # ASSUMPTION E30
        self.latch = data
        self.c('ram_read_map%d' % ((self.gc[0][6] >> 2) & 3))
        return 0xFF if res is None else res

    def mem_write(self, a, d):
        if not self.dack0_n:
            self.c('mem_dack0_blocked')
            return
        o = self.ram_offset(a)
        if o is None:
            return
        pa = self.plane_addr(o)
        oddeven = not bit(self.seq[4], 2)
        self.c('ram_write_map%d_oe%d' % ((self.gc[0][6] >> 2) & 3, int(oddeven)))
        for p in range(4):
            if not bit(self.seq[2], p):
                continue
            if oddeven and (o & 1) != (p & 1):
                continue
            i, q = p >> 1, p & 1
            g = self.gc[i]
            n = 2 * self.gc_pos[i] + q
            wm = g[5] & 3
            lat = self.latch[p]
            fn = (g[3] >> 3) & 3
            if wm == 3:
                self.c('write_mode3')
                continue                            # ASSUMPTION E29
            if wm == 1:
                v = lat
            else:
                if wm == 0:
                    v = ror8(d, g[3] & 7)          # ASSUMPTION E33: rotate right
                    if n < 4 and bit(g[1], n):
                        v = 0xFF if bit(g[0], n) else 0
                        self.c('set_reset_used')
                else:
                    v = 0xFF if bit(d, n) else 0
                v = [v, v & lat, v | lat, v ^ lat][fn]
                v = (v & g[8]) | (lat & ~g[8] & 0xFF)
                self.c('fn_%d' % fn)
            self.c('write_mode%d' % wm)
            self.planes[p][pa] = v

    # ------------------------------------------------------------ CRTC
    def crtc_flags(self):
        """Flags of the current character (evaluated on entering it)."""
        hc = self.hc
        r = self.crtc
        self.hb = 1 if (hc == r[2] or (self.hb and (hc & 31) != (r[3] & 31))) else 0
        self.hs = 1 if (hc == r[4] or (self.hs and (hc & 31) != (r[5] & 31))) else 0
        e = Pipe()
        e.de = 1 if (hc <= r[1] and self.vc <= self.VDE) else 0
        e.blank = self.hb | self.vb
        e.hs = self.hs
        e.vs = self.vsl
        cs, ce = r[0xA] & 31, r[0xB] & 31
        cl = (r[0xE] << 8) | r[0xF]
        # ASSUMPTION E16: CS <= rs < CE
        e.cursor = 1 if (self.ma == cl and cs <= self.rs < ce) else 0
        e.ul = 1 if self.rs == (r[0x14] & 31) else 0
        e.hcodd = hc & 1
        e.ma = self.ma
        return e

    def disp_addr(self):
        mc = self.crtc[0x17]
        ma = self.ma
        if bit(mc, 6):
            a = ma
        else:
            a = ((ma << 1) & 0xFFFF) | (bit(ma, 15) if bit(mc, 5) else bit(ma, 13))
            self.c('crtc_word_mode')
        if not bit(mc, 0):
            a = (a & ~(1 << 13)) | (bit(self.rs, 0) << 13)
        if not bit(mc, 1):
            a = (a & ~(1 << 14)) | (bit(self.rs, 1) << 14)
        if not self.ext():
            a &= 0x3FFF
        return a

    def vertical_step(self):
        if self.vc == self.VT + 1:
            self.vc = 0
            self.rs = self.crtc[8] & 31
            self.row_start = (self.crtc[0xC] << 8) | self.crtc[0xD]
            self.c('frame_start')
        else:
            left = self.vc
            self.vc = (self.vc + 1) & 0x3FF
            inc = False
            if self.rs == (self.crtc[9] & 31):
                self.rs = 0
                inc = True
            else:
                self.rs = (self.rs + 1) & 31
            if left == self.LC:
                self.row_start = 0             # ASSUMPTION E14
                self.c('line_compare_hit')
            elif inc:
                self.row_start = (self.row_start + 2 * self.crtc[0x13]) & 0xFFFF
        vc = self.vc
        self.vb = 1 if (vc == self.VBS or (self.vb and (vc & 31) != (self.crtc[0x16] & 31))) else 0
        vre = self.crtc[0x11]
        vs = 1 if (vc == self.VRS or (self.vsl and (vc & 15) != (vre & 15))) else 0
        if vs and not self.vsl:
            self.blink = (self.blink + 1) & 31
            self.c('vretrace_start')
            if not bit(vre, 5) and bit(vre, 4):
                if not self.intlatch:
                    self.c('vint_set')
                self.intlatch = 1
        self.vsl = vs

    def crtc_step(self):
        r = self.crtc
        if self.hc == r[4]:
            # ASSUMPTION E13: vertical clock = start of horizontal retrace
            go = True
            if bit(r[0x17], 2):
                go = self.vdiv == 1
                self.vdiv ^= 1
                self.c('hrtc_div2')
            if go:
                self.vertical_step()
        hcn = 0 if self.hc == r[0] + 1 else (self.hc + 1) & 0x1FF
        if hcn == 0:
            self.ma = (self.row_start + bit(r[5], 7)) & 0xFFFF
            if bit(r[5], 7):
                self.c('start_odd')
        elif not bit(r[0x17], 3) or (self.hc & 1):
            self.ma = (self.ma + 1) & 0xFFFF
        if bit(r[0x17], 3):
            self.c('count_by_two')
        self.hc = hcn

    def crtc_reset(self):
        # ASSUMPTION E2
        self.hc = self.vc = self.rs = 0
        self.row_start = self.ma = 0
        self.hb = self.hs = self.vb = self.vsl = 0
        self.vdiv = 0
        self.intlatch = 0

    # ---------------------------------------------------- display stage
    def fetch(self, e):
        a = self.disp_addr()
        e.planes = [self.planes[p][a] for p in range(4)]
        e.gcgraph = bit(self.gc[0][6], 0)
        if not e.gcgraph:
            ch = e.planes[0]
            at = e.planes[1]
            cms = self.seq[3]
            mb, ma_ = cms & 3, (cms >> 2) & 3
            # ASSUMPTION E17
            if self.ext() and bit(self.seq[4], 0) and ma_ != mb and bit(at, 3):
                m = ma_
                self.c('charmap_A')
            elif self.ext():
                m = mb
            else:
                m = 0
            fa = (m << 14) | (ch << 5) | self.rs
            if not self.ext():
                fa &= 0x3FFF
            e.font = self.planes[2][fa]
            self.c('font_fetch_map%d' % m)
        else:
            e.font = e.planes[2]

    def serial(self, e, w):
        """C0..C3 per dot of one fetched character (graphics serializer)."""
        out = [0] * w
        sl = bit(self.seq[1], 2)
        for i in range(2):
            pa, pb = e.planes[2 * i], e.planes[2 * i + 1]
            sr = bit(self.gc[i][5], 5)
            for j in range(min(w, 8)):
                if sl:
                    # ASSUMPTION E19
                    by = pb if e.hcodd else pa
                    ca, cb = bit(by, 7 - j), 0
                elif sr:
                    by = pa if j < 4 else pb
                    k = j & 3
                    cb, ca = bit(by, 7 - 2 * k), bit(by, 6 - 2 * k)
                else:
                    ca, cb = bit(pa, 7 - j), bit(pb, 7 - j)
                out[j] |= (ca << (2 * i)) | (cb << (2 * i + 1))
        # ASSUMPTION E32: 9th dot of a graphics character is 0
        return out

    def form(self, e, cur, w):
        am = self.areg[0x10]
        if e.gcgraph:
            low = self.serial(e, w)
        else:
            low = [e.planes[1] & 15] * w
        glyph = e.font
        blink_en = bit(am, 3)
        blink_off = bit(self.blink, 4)
        idx = [0] * w
        for j in range(w):
            at = (e.planes[1] & 0xF0) | low[j]
            if bit(am, 0):
                v = at & 15
                if blink_en and blink_off:
                    v |= 8                         # ASSUMPTION E20
                idx[j] = v
                continue
            if j < 8:
                g = bit(glyph, 7 - j)
            else:
                lg = (e.planes[0] & 0xE0) == 0xC0
                g = bit(glyph, 0) if (bit(am, 2) and lg) else 0
            fg = at & 15
            bg = ((at >> 4) & 7) if blink_en else (at >> 4)
            if bit(am, 1) and e.ul and (at & 0x77) == 0x01:
                g = 1                               # ASSUMPTION E22
            if blink_en and bit(at, 7) and blink_off:
                g = 0
            if cur and not bit(self.blink, 3):
                g = 1                               # ASSUMPTION E23
            idx[j] = fg if g else bg
        return idx

    def boundary(self):
        self.wchar = self.wnew()
        e = self.crtc_flags()
        self.fetch(e)
        if self.lpff and not self.lp_prev:
            self.lp = e.ma
            self.c('lp_latch')
        self.lp_prev = self.lpff
        self.hist = self.hist[1:] + [e]
        if self.reset_drv:
            self.crtc_reset()
        else:
            self.crtc_step()
        h = self.hist                                # h[5] = k, h[3] = k-2
        r = self.crtc
        skew = (r[3] >> 5) & 3
        cskew = (r[0xB] >> 5) & 3
        hdel = (r[5] >> 5) & 3
        E, N = h[3], h[4]
        w = self.wchar
        self.cur_idx = self.form(E, h[3 - cskew].cursor and not self.areg[0x10] & 1, w)
        self.nxt_idx = self.form(N, h[4 - cskew].cursor and not self.areg[0x10] & 1, w)
        # ASSUMPTION E18: data k-2, display enable k-1-skew, cursor
        # k-2-cursor skew, blank k-1 (attribute chip), retraces straight
        # from the CRTC: horizontal k-delay, vertical k.
        self.de_out = h[4 - skew].de
        self.blank_out = h[4].blank
        en = bit(r[0x17], 7)
        self.hs_out = h[5 - hdel].hs & en
        self.vs_out = h[5].vs & en
        self.c('skew_%d' % skew)
        self.c('cskew_%d' % cskew)
        self.c('hdelay_%d' % hdel)
        am = self.areg[0x10]
        if E.de:
            self.c('amode_%s' % ('gfx' if am & 1 else 'text'))
            for b in range(4):
                if bit(am, b):
                    self.c('amode_bit%d' % b)
            if h[3 - cskew].cursor and not am & 1:
                self.c('cursor_char')
            if E.ul and bit(am, 1) and not am & 1:
                self.c('underline_row')
            self.c('gc_shift%d_sl%d' % (bit(self.gc[0][5], 5), bit(self.seq[1], 2)))
            self.c('clock_w%d_div%d' % (w, bit(self.seq[1], 3)))

    def dot(self, j):
        w = self.wchar
        pan = self.areg[0x13]
        if w == 9:
            sh = 0 if pan >= 8 else pan + 1          # TR p.61 / ASSUMPTION E24
        else:
            sh = pan & 7
        if pan:
            self.c('pan_%d_w%d' % (pan, w))
        s = j + sh
        idx = self.cur_idx[s] if s < w else self.nxt_idx[s - w]
        idx &= self.areg[0x12] & 15
        if self.blank_out:
            col = 0
        elif not self.de_out or not self.attr_idx & 0x20:
            col = self.areg[0x11]                    # ASSUMPTION E27
        else:
            col = self.pal[idx]
        self.last_color = col
        vid = col if self.p1 else col & 0x1F
        hs = self.hs_out ^ bit(self.misc, 6)
        vs = self.vs_out ^ bit(self.misc, 7)
        oe = 1 - bit(self.misc, 4)
        de = self.de_out
        return vid | (hs << 6) | (vs << 7) | (self.blank_out << 8) | (de << 9) | (oe << 10)

    def pulse(self):
        """One master pulse of both oscillators (bench T command)."""
        if self.reset_drv:
            self.crtc_reset()
        sel = (self.misc >> 2) & 3
        if sel not in (0, 1):
            return                                  # EXT tied off / no clock
        if not self.running():
            return
        if bit(self.seq[1], 3):
            d = self.half == 0
            self.half ^= 1
            if not d:
                return
        else:
            self.half = 0
        if self.dotcnt == 0:
            self.boundary()
        self.out.append(self.dot(self.dotcnt))
        self.dotcnt += 1
        if self.dotcnt >= self.wchar:
            self.dotcnt = 0

    # ------------------------------------------------------- pins/debug
    def set_lpen(self, v):
        if self.lpen_n and not v:
            self.lpff = 1                            # U18 clocked by -LPEN IN fall
        self.lpen_n = v

    def set_reset_drv(self, v):
        self.reset_drv = v
        if v:
            self.misc = 0
            self.fcr = 0
            self.crtc_reset()

    def irq(self):
        return self.intlatch, 1 - bit(self.crtc[0x11], 5)

    def dbg_reg(self, a):
        if a < 5:
            return self.seq[a]
        if a == 5:
            return self.seq_idx
        if 0x10 <= a <= 0x28:
            return self.crtc[a - 0x10]
        if a == 0x29:
            return self.crtc_idx
        if a == 0x2A:
            return self.lp >> 8
        if a == 0x2B:
            return self.lp & 0xFF
        if 0x30 <= a <= 0x38:
            return self.gc[0][a - 0x30]
        if a == 0x39:
            return self.gc_idx
        if a == 0x3A:
            return self.gc_pos[0]
        if a == 0x3B:
            return self.gc_pos[1]
        if 0x40 <= a <= 0x4F:
            return self.pal[a - 0x40]
        if 0x50 <= a <= 0x53:
            return self.areg[a - 0x40]
        if a == 0x54:
            return self.attr_idx
        if a == 0x55:
            return self.attr_ff
        if a == 0x60:
            return self.misc
        if a == 0x61:
            return self.fcr
        if 0x62 <= a <= 0x65:
            return self.latch[a - 0x62]
        if a == 0x66:
            return self.lpff
        if a == 0x67:
            return self.intlatch
        if a == 0x68:
            return self.blink
        return 0xFF


DBG_REGS = (list(range(0, 6)) + list(range(0x10, 0x2C)) + list(range(0x30, 0x3C))
            + list(range(0x40, 0x56)) + list(range(0x60, 0x69)))


# --------------------------------------------------------------- runner
def rle(vals):
    out = []
    for v in vals:
        if out and out[-1][1] == v:
            out[-1][0] += 1
        else:
            out.append([1, v])
    return out


def parse_hex_or_z(s):
    return None if s.upper() == 'Z' else int(s, 16)


def run(script, trace_path, rom=None, cov_path=None):
    m = EGA(rom)
    fails = []
    lines = []
    last = []
    last_irq = None

    def note_irq():
        nonlocal last_irq
        s = m.irq()
        if s != last_irq:
            lines.append('I %d %d' % s)
            last_irq = s

    for ln, raw in enumerate(open(script), 1):
        t = raw.split('#')[0].split()
        if not t:
            continue
        op = t[0]
        h = [parse_hex_or_z(x) for x in t[1:]] if op not in ('T', 'XDOTS', 'XPIX') else None

        def expect(got, want, what):
            if got != want:
                fails.append('line %d %s: got %s expected %s' % (ln, what, got, want))

        if op == 'T':
            m.out = []
            for _ in range(int(t[1])):
                m.pulse()
            last = m.out
            lines.append('T %d %d' % (int(t[1]), len(last)))
            for c, v in rle(last):
                lines.append('V %d %03x' % (c, v))
        elif op in ('OW', 'OWN'):
            m.io_write(h[0], h[1], aen=1 if op == 'OWN' else 0)
        elif op in ('OR', 'ORN'):
            v = m.io_read(h[0], aen=1 if op == 'ORN' else 0)
            lines.append('R %04x %s' % (h[0], 'Z' if v is None else '%02x' % v))
            if len(h) > 1:
                expect(v, h[1], 'OR %04x' % h[0])
        elif op == 'MW':
            m.mem_write(h[0], h[1])
        elif op == 'MR':
            v = m.mem_read(h[0])
            lines.append('R %05x %s' % (h[0], 'Z' if v is None else '%02x' % v))
            if len(h) > 1:
                expect(v, h[1], 'MR %05x' % h[0])
        elif op == 'RST':
            m.set_reset_drv(h[0])
        elif op == 'SW':
            m.sw = h[0] & 15
        elif op == 'P1':
            m.p1 = h[0] & 1
        elif op == 'P3':
            m.p3 = h[0] & 1
        elif op == 'FEAT':
            m.feat = h[0] & 3
        elif op == 'LP':
            m.set_lpen(h[0] & 1)
        elif op == 'LPSW':
            m.lpsw_n = h[0] & 1
        elif op == 'DACK':
            m.dack0_n = h[0] & 1
        elif op == 'DUMPR':
            lines.append('D ' + ' '.join('%02x' % m.dbg_reg(a) for a in DBG_REGS))
        elif op == 'DUMPM':
            p, a0, n = h
            lines.append('M %d %04x ' % (p, a0) + ''.join(
                '%02x' % m.planes[p][(a0 + i) & 0xFFFF] for i in range(n)))
        elif op == 'XREG':
            expect(m.dbg_reg(h[0]), h[1], 'XREG %02x' % h[0])
        elif op == 'XMEM':
            expect(m.planes[h[0]][h[1]], h[2], 'XMEM %d %04x' % (h[0], h[1]))
        elif op == 'XDOTS':
            expect(len(last), int(t[1]), 'XDOTS')
        elif op == 'XPIX':
            k, mask, want = int(t[1]), int(t[2], 16), int(t[3], 16)
            got = last[k] & mask if k < len(last) else None
            expect(got, want, 'XPIX %d' % k)
        elif op == 'XIRQ':
            expect(m.irq()[0], h[0], 'XIRQ')
        else:
            raise SystemExit('%s:%d: unknown command %s' % (script, ln, op))
        note_irq()
    with open(trace_path, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    if cov_path:
        with open(cov_path, 'w') as f:
            json.dump(m.cov, f)
    return fails, m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('script')
    ap.add_argument('trace')
    ap.add_argument('--rom')
    ap.add_argument('--coverage')
    a = ap.parse_args()
    rom = open(a.rom, 'rb').read() if a.rom else None
    fails, _ = run(a.script, a.trace, rom, a.coverage)
    for f in fails[:20]:
        print('FAIL: %s: %s' % (a.script, f))
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
