#!/usr/bin/env python3
"""Reference model of the IBM PS/2 Display Adapter (ISA VGA, 256 KB).

Written from IBM's documents -- the PS/2 Hardware Interface Technical
Reference "Video Subsystem (Type 1)" (HITR, May 1988) and the VGA/XGA
Technical Reference (VGAXGA, May 1992, "p.2-N") -- and the contract in
spec/spec.md, not from the RTL. Behaviour the documents leave open is tagged
"ASSUMPTION Vn" with the same tag as the spec ledger and the RTL; where the
EGA technical reference documents a shared function, its ledger tag (En of
design/ibm_ega) is cited.

Time model. A bench script advances time in master pulses ("T n": n clocks
in which every oscillator enable pulses). Every bus operation is atomic
between two pulses. The video output is one value per dot.

Command line (lockstep partner of tb/vga_tb.cpp):

    vga_model.py SCRIPT TRACE_OUT [--rom ROM32K] [--coverage COV]

runs SCRIPT (format at the top of tb/vga_tb.cpp), writes the same trace the
bench writes, and checks every expectation in the script. Exit status 1 on
a failed expectation.
"""
import argparse
import json
import sys


def bit(v, n):
    return (v >> n) & 1


def ror8(v, n):
    n &= 7
    return ((v >> n) | (v << (8 - n))) & 0xFF


# stored register bits (Figures 2-29 to 2-89; ASSUMPTION V7)
SEQ_MASK = [0x03, 0x3D, 0x0F, 0x3F, 0x0E]
CRTC_MASK = {0x08: 0x7F, 0x0A: 0x3F, 0x0B: 0x7F, 0x14: 0x7F, 0x17: 0xEF}
GC_MASK = [0x0F, 0x0F, 0x0F, 0x1F, 0x03, 0x7B, 0x0F, 0x0F, 0xFF]
ATTR_MASK = {0x10: 0xEF, 0x11: 0xFF, 0x12: 0x3F, 0x13: 0x0F, 0x14: 0x0F}
SENSE_REF = 26          # ASSUMPTION V21, DAC code units with a 75-ohm load


class Pipe:
    """One character boundary: the CRTC flags and the fetched data."""
    __slots__ = ('de', 'blank', 'hs', 'cursor', 'ul', 'hcodd', 'planes',
                 'font', 'gcgraph', 'ma')

    def __init__(self):
        self.de = self.blank = self.hs = 0
        self.cursor = self.ul = self.hcodd = 0
        self.planes = [0, 0, 0, 0]
        self.font = 0
        self.gcgraph = 0
        self.ma = 0


class VGA:
    def __init__(self, rom=None):
        self.rom = rom if rom is not None else bytes(32768)
        self.cov = {}
        self.fast = False
        self.power_on()

    def c(self, k, n=1):
        self.cov[k] = self.cov.get(k, 0) + n

    # ------------------------------------------------------------ state
    def power_on(self):
        # ASSUMPTION V1: everything cleared
        self.planes = [bytearray(65536) for _ in range(4)]
        self.misc = 0
        self.fcr = 0
        self.vse = 0
        self.pos102 = 0
        self.seq_idx = 0
        self.seq = [0] * 5
        self.crtc_idx = 0
        self.crtc = [0] * 25
        self.gc_idx = 0
        self.gc = [0] * 9
        self.attr_idx = 0
        self.attr_ff = 0
        self.pal = [0] * 16
        self.areg = {0x10: 0, 0x11: 0, 0x12: 0, 0x13: 0, 0x14: 0}
        self.latch = [0, 0, 0, 0]
        self.dac = [(0, 0, 0)] * 256
        self.dac_addr = 0
        self.dac_sub = 0
        self.dac_rmode = 0
        self.dac_hold = [0, 0]
        self.pelmask = 0
        self.intlatch = 0
        self.blink = 0
        self.pan_lc = 0
        self.reset_drv = 0
        self.dack0_n = 1
        self.load = 7
        self.hc = self.vc = self.rs = 0
        self.row_start = self.ma = 0
        self.hb = self.hs = self.vb = self.vsl = 0
        self.vdiv = 0
        self.dphase = 0
        self.dotcnt = 0
        self.half = 0
        self.wchar = 9
        self.hist = [Pipe() for _ in range(8)]
        self.cur = self.nxt = None              # (Pipe, cursor) of the displayed chars
        self.cur_idx = self.nxt_idx = None
        self.de_out = self.blank_out = self.hs_out = self.vs_out = 0
        self.rgb = (0, 0, 0)
        self.last_j = 0
        self.out = []

    # ------------------------------------------------------- derived regs
    def ov(self, b):
        return bit(self.crtc[7], b)

    @property
    def VT(self):
        return self.crtc[6] | (self.ov(0) << 8) | (self.ov(5) << 9)

    @property
    def VDE(self):
        return self.crtc[0x12] | (self.ov(1) << 8) | (self.ov(6) << 9)

    @property
    def VRS(self):
        return self.crtc[0x10] | (self.ov(2) << 8) | (self.ov(7) << 9)

    @property
    def VBS(self):
        return self.crtc[0x15] | (self.ov(3) << 8) | (bit(self.crtc[9], 5) << 9)

    @property
    def LC(self):
        return self.crtc[0x18] | (self.ov(4) << 8) | (bit(self.crtc[9], 6) << 9)

    def running(self):
        return self.seq[0] == 3

    def wnew(self):
        return 8 if self.seq[1] & 1 else 9

    def ext(self):
        return bit(self.seq[4], 1)

    def chain4(self):
        return bit(self.seq[4], 3)

    def enabled(self):
        # ASSUMPTION V4: 46E8h bit 3 AND POS 102h bit 0
        return bit(self.vse, 3) and (self.pos102 & 1)

    def setup(self):
        return bit(self.vse, 4)

    # ------------------------------------------------------------ decode
    aen = 0

    def io_port(self, a, d='w'):
        """Decoded port name for a write (d='w') or read ('r'), else None."""
        if self.aen:
            return None
        a &= 0xFFFF
        if a == 0x46E8:
            return 'vse' if d == 'w' else None           # write only
        if a == 0x0102:
            return 'pos' if self.setup() else None       # HITR p.10
        if not self.enabled():
            return None
        if (a >> 8) & 3 != 3:                            # ASSUMPTION V3: A9-A0
            return None
        lo = a & 0xFF
        x = 0xD0 if self.misc & 1 else 0xB0
        if lo == 0xC0:
            return 'attr'
        if lo == 0xC1:
            return 'attr_data' if d == 'r' else None     # ASSUMPTION V6
        if lo == 0xC2:
            return 'c2'
        if lo in (0xC4, 0xC5):
            return 'seqa' if lo == 0xC4 else 'seqd'
        if 0xC6 <= lo <= 0xC9:
            if self.setup():
                return None                              # HITR p.10
            return {0xC6: 'pelmask', 0xC7: 'dac_ra', 0xC8: 'dac_wa', 0xC9: 'dac_data'}[lo]
        if lo == 0xCA:
            return 'fcr_rd' if d == 'r' else None
        if lo == 0xCC:
            return 'misc_rd' if d == 'r' else None
        if lo in (0xCE, 0xCF):
            return 'gca' if lo == 0xCE else 'gcd'
        if lo == x + 4:
            return 'crtca'
        if lo == x + 5:
            return 'crtcd'
        if lo == x + 0xA:
            return 'xa'
        return None

    def c_bits(self, name, v, n):
        self.c('w_' + name)
        for b in range(n):
            self.c('wb_%s_%d_%d' % (name, b, bit(v, b)))

    def io_write(self, a, d, aen=0):
        self.aen = aen
        p = self.io_port(a, 'w')
        self.aen = 0
        if p is None:
            self.c('io_write_undecoded')
            return
        self.c('io_w_' + p)
        if p == 'vse':
            if not self.reset_drv:
                self.vse = d
                self.c_bits('vse', d, 8)
        elif p == 'pos':
            if not self.reset_drv:
                self.pos102 = d & 1
                self.c('pos_%d' % (d & 1))
        elif p == 'attr':
            self.attr_write(d)
        elif p == 'c2':
            if not self.reset_drv:
                self.misc = d
                self.c_bits('misc', d, 8)
        elif p == 'seqa':
            self.seq_idx = d & 7
        elif p == 'seqd':
            i = self.seq_idx
            if i < 5:
                v = d & SEQ_MASK[i]
                self.seq[i] = v
                self.c_bits('seq%d' % i, v, 8)
                if i == 0 and v != 3:
                    self.dotcnt = 0                    # ASSUMPTION V8
                    self.half = 0
        elif p == 'gca':
            self.gc_idx = d & 0x0F
        elif p == 'gcd':
            i = self.gc_idx
            if i < 9:
                v = d & GC_MASK[i]
                self.gc[i] = v
                self.c_bits('gc%d' % i, v, 8)
        elif p == 'crtca':
            self.crtc_idx = d & 0x1F
        elif p == 'crtcd':
            i = self.crtc_idx
            if i < 25:
                if bit(self.crtc[0x11], 7) and i <= 7:
                    # p.2-70: Protect, Overflow bit 4 (LC8) still written
                    self.c('crtc_protected')
                    if i == 7:
                        self.crtc[7] = (self.crtc[7] & ~0x10) | (d & 0x10)
                else:
                    v = d & CRTC_MASK.get(i, 0xFF)
                    self.crtc[i] = v
                    self.c_bits('crtc%02x' % i, v, 8)
                if i == 0x11 and not bit(self.crtc[0x11], 4):
                    self.intlatch = 0
        elif p == 'xa':
            self.fcr = d
            self.c_bits('fcr', d, 8)
        elif p == 'pelmask':
            self.pelmask = d
            self.c_bits('pelmask', d, 8)
        elif p == 'dac_wa':
            self.dac_addr, self.dac_sub, self.dac_rmode = d, 0, 0
        elif p == 'dac_ra':
            self.dac_addr, self.dac_sub, self.dac_rmode = d, 0, 1
        elif p == 'dac_data':
            # ASSUMPTION V20: one address register and one shared sub-index
            if self.dac_rmode:
                self.c('dac_write_in_read_mode')
            if self.dac_sub < 2:
                self.dac_hold[self.dac_sub] = d & 0x3F
                self.dac_sub += 1
            else:
                self.dac[self.dac_addr] = (self.dac_hold[0], self.dac_hold[1], d & 0x3F)
                self.c('dac_entry_written')
                for k, v in enumerate((self.dac_hold[0], self.dac_hold[1], d & 0x3F)):
                    for b in range(6):
                        self.c('dac_bit_%d_%d_%d' % (k, b, bit(v, b)))
                self.dac_sub = 0
                self.dac_addr = (self.dac_addr + 1) & 0xFF

    def attr_write(self, d):
        if self.attr_ff == 0:
            self.attr_idx = d & 0x3F
        else:
            i = self.attr_idx & 0x1F
            if i < 16:
                # EGA E27: palette loads only while IPAS = 0
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
        p = self.io_port(a, 'r')
        self.aen = 0
        if p is None:
            if self.io_port(a, 'w') is not None or (a & 0x3FF) == 0x3C3:
                self.c('io_read_writeonly')
            return None
        self.c('io_r_' + p)
        if p == 'attr':
            return self.attr_idx
        if p == 'attr_data':
            i = self.attr_idx & 0x1F
            if i < 16:
                return self.pal[i]                       # ASSUMPTION V6
            return self.areg.get(i, 0)                   # ASSUMPTION V7
        if p == 'c2':
            s = self.sense()
            self.c('sense_%d' % s)
            return (self.intlatch << 7) | (s << 4)
        if p == 'seqa':
            return self.seq_idx
        if p == 'seqd':
            return self.seq[self.seq_idx] if self.seq_idx < 5 else 0
        if p == 'pelmask':
            return self.pelmask
        if p == 'dac_ra':
            return 3 if self.dac_rmode else 0
        if p == 'dac_wa':
            return self.dac_addr
        if p == 'dac_data':
            if not self.dac_rmode:
                self.c('dac_read_in_write_mode')
            v = self.dac[self.dac_addr][self.dac_sub]
            self.c('dac_read_%d' % self.dac_sub)
            if self.dac_sub < 2:
                self.dac_sub += 1
            else:
                self.dac_sub = 0
                self.dac_addr = (self.dac_addr + 1) & 0xFF
            return v
        if p == 'fcr_rd':
            return self.fcr
        if p == 'misc_rd':
            return self.misc
        if p == 'gca':
            return self.gc_idx
        if p == 'gcd':
            return self.gc[self.gc_idx] if self.gc_idx < 9 else 0
        if p == 'crtca':
            return self.crtc_idx
        if p == 'crtcd':
            return self.crtc[self.crtc_idx] if self.crtc_idx < 25 else 0
        if p == 'xa':
            self.attr_ff = 0                             # p.2-89
            return (self.vsl << 3) | (1 - self.de_out)  # p.2-45
        if p == 'pos':
            return self.pos102
        return None

    def sense(self):
        """ASSUMPTION V21: every output below the reference; an output
        without a load is at twice the voltage."""
        r, g, b = self.rgb if not self.fast else self.fast_rgb()
        ok = 1
        for v, ld in ((r, bit(self.load, 2)), (g, bit(self.load, 1)), (b, bit(self.load, 0))):
            e = v if ld else 2 * v
            if e >= SENSE_REF:
                ok = 0
        return ok

    # ------------------------------------------------------- CPU memory
    def ram_offset(self, a):
        if not self.dack0_n or not bit(self.misc, 1) or not self.enabled():
            return None
        m = (self.gc[6] >> 2) & 3
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
        m = (self.gc[6] >> 2) & 3
        if self.chain4():
            pa = (o & 0xFFFC) | ((o >> 14) & 3)          # ASSUMPTION V15
            self.c('chain4_%d' % m)
        elif bit(self.gc[6], 1):
            # ASSUMPTION V13 (EGA E28)
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
        if 0xC0000 <= a <= 0xC7FFF:
            self.c('rom_read')
            return self.rom[a - 0xC0000]
        o = self.ram_offset(a)
        if o is None:
            return None
        pa = self.plane_addr(o)
        data = [self.planes[p][pa] for p in range(4)]
        g = self.gc
        self.latch = data
        self.c('ram_read_map%d' % ((g[6] >> 2) & 3))
        if bit(g[5], 3):
            self.c('read_mode1')
            v = 0xFF
            for n in range(4):
                if bit(g[7], n):                         # p.2-87: 1 = compared
                    ref = 0xFF if bit(g[2], n) else 0
                    v &= ~(data[n] ^ ref) & 0xFF
            return v
        if self.chain4():
            m = o & 3
            self.c('read_chain4')
        elif bit(g[5], 4):
            m = (g[4] & 2) | (o & 1)
            self.c('read_oddeven')
        else:
            m = g[4] & 3
        self.c('read_mode0_map%d' % m)
        return data[m]

    def mem_write(self, a, d):
        if not self.dack0_n:
            self.c('mem_dack0_blocked')
            return
        o = self.ram_offset(a)
        if o is None:
            return
        pa = self.plane_addr(o)
        g = self.gc
        oddeven = not bit(self.seq[4], 2)
        self.c('ram_write_map%d_oe%d_c4%d' % ((g[6] >> 2) & 3, int(oddeven), self.chain4()))
        wm = g[5] & 3
        fn = (g[3] >> 3) & 3
        rot = ror8(d, g[3] & 7)                          # p.2-82: rotate right
        for p in range(4):
            if not bit(self.seq[2], p):
                continue
            if self.chain4():
                if (o & 3) != p:
                    continue
            elif oddeven and (o & 1) != (p & 1):
                continue
            lat = self.latch[p]
            mask = g[8]
            if wm == 1:
                v = lat
            else:
                if wm == 0:
                    v = (0xFF if bit(g[0], p) else 0) if bit(g[1], p) else rot
                    if bit(g[1], p):
                        self.c('set_reset_used')
                elif wm == 2:
                    v = 0xFF if bit(d, p) else 0
                else:
                    v = 0xFF if bit(g[0], p) else 0      # p.2-85
                    mask = g[8] & rot
                v = [v, v & lat, v | lat, v ^ lat][fn]
                v = (v & mask) | (lat & ~mask & 0xFF)
                self.c('fn_%d' % fn)
            self.c('write_mode%d' % wm)
            self.planes[p][pa] = v

    # ------------------------------------------------------------ CRTC
    def crtc_flags(self):
        hc = self.hc
        r = self.crtc
        ehb = (r[3] & 31) | (bit(r[5], 7) << 5)
        self.hb = 1 if (hc == r[2] or (self.hb and (hc & 63) != ehb)) else 0
        self.hs = 1 if (hc == r[4] or (self.hs and (hc & 31) != (r[5] & 31))) else 0
        e = Pipe()
        e.de = 1 if (hc <= r[1] and self.vc <= self.VDE) else 0
        e.blank = self.hb | self.vb
        e.hs = self.hs
        cs, ce = r[0xA] & 31, r[0xB] & 31
        cl = (r[0xE] << 8) | r[0xF]
        # ASSUMPTION V25 (EGA E16), Cursor Start bit 5 = off (p.2-65)
        e.cursor = 1 if (self.ma == cl and not bit(r[0xA], 5) and cs <= self.rs < ce) else 0
        e.ul = 1 if self.rs == (r[0x14] & 31) else 0
        e.hcodd = hc & 1
        e.ma = self.ma
        return e

    def disp_addr(self):
        r = self.crtc
        ma = self.ma
        if bit(r[0x14], 6):
            a = ((ma << 2) & 0xFFFC) | ((ma >> 12) & 3)  # Figure 2-65 doubleword
            self.c('crtc_dword_mode')
        elif not bit(r[0x17], 6):
            a = ((ma << 1) & 0xFFFF) | (bit(ma, 15) if bit(r[0x17], 5) else bit(ma, 13))
            self.c('crtc_word_mode')
        else:
            a = ma
        if not bit(r[0x17], 0):
            a = (a & ~(1 << 13)) | (bit(self.rs, 0) << 13)
        if not bit(r[0x17], 1):
            a = (a & ~(1 << 14)) | (bit(self.rs, 1) << 14)
        if not self.ext():
            a &= 0x3FFF
        return a

    def vertical_step(self):
        r = self.crtc
        self.vstart = 0
        self.lchit = 0
        if self.vc == self.VT + 1:
            self.vc = 0
            self.rs = r[8] & 31
            self.row_start = ((r[0xC] << 8) + r[0xD] + ((r[8] >> 5) & 3)) & 0xFFFF   # V11
            self.dphase = 0
            self.c('frame_start')
        else:
            left = self.vc
            self.vc = (self.vc + 1) & 0x3FF
            dsc = bit(r[9], 7)
            # ASSUMPTION V9: double scan divides the row-scan clock by 2
            tick = (not dsc) or self.dphase
            self.dphase = (1 - self.dphase) if dsc else 0
            if dsc:
                self.c('double_scan_line')
            wrap = False
            if tick:
                if self.rs == (r[9] & 31):
                    self.rs = 0
                    wrap = True
                else:
                    self.rs = (self.rs + 1) & 31
            if left == self.LC:
                self.row_start = 0                       # p.2-103
                self.dphase = 0
                self.lchit = 1
                self.c('line_compare_hit')
            elif wrap:
                self.row_start = (self.row_start + 2 * r[0x13]) & 0xFFFF
        vc = self.vc
        self.vb = 1 if (vc == self.VBS or (self.vb and (vc & 0xFF) != r[0x16])) else 0   # V10
        vre = r[0x11]
        vs = 1 if (vc == self.VRS or (self.vsl and (vc & 15) != (vre & 15))) else 0
        if vs and not self.vsl:
            self.vstart = 1
            self.c('vretrace_start')
            if not bit(vre, 5) and bit(vre, 4):
                if not self.intlatch:
                    self.c('vint_set')
                self.intlatch = 1
        self.vsl = vs

    def crtc_step(self):
        r = self.crtc
        self.vstart = self.lchit = 0
        if self.hc == r[4]:
            go = True
            if bit(r[0x17], 2):
                go = self.vdiv == 1
                self.vdiv ^= 1
                self.c('hrtc_div2')
            if go:
                self.vertical_step()
        hcn = 0 if self.hc == r[0] + 4 else (self.hc + 1) & 0x1FF   # HT+5 (p.2-56)
        if hcn == 0:
            self.ma = self.row_start
        elif bit(r[0x14], 5):
            if (self.hc & 3) == 3:
                self.ma = (self.ma + 1) & 0xFFFF
            self.c('count_by_four')
        elif not bit(r[0x17], 3) or (self.hc & 1):
            self.ma = (self.ma + 1) & 0xFFFF
        if bit(r[0x17], 3):
            self.c('count_by_two')
        self.hc = hcn

    def crtc_reset(self):
        # ASSUMPTION V2 (EGA E2)
        self.hc = self.vc = self.rs = 0
        self.row_start = self.ma = 0
        self.hb = self.hs = self.vb = self.vsl = 0
        self.vdiv = 0
        self.dphase = 0
        self.intlatch = 0
        self.vstart = self.lchit = 0

    # ---------------------------------------------------- display stage
    def fetch(self, e):
        a = self.disp_addr()
        e.planes = [self.planes[p][a] for p in range(4)]
        e.gcgraph = bit(self.gc[6], 0)
        if not e.gcgraph:
            ch, at = e.planes[0], e.planes[1]
            cms = self.seq[3]
            ma_ = ((cms >> 2) & 3) | (bit(cms, 5) << 2)
            mb = (cms & 3) | (bit(cms, 4) << 2)
            if self.ext() and ma_ != mb and bit(at, 3):
                m = ma_
                self.c('charmap_A')
            elif self.ext():
                m = mb
            else:
                m = 0
            # Figure 2-34: map n at the ({n1 n0 n2} x 8 KB) table, V12
            fa = (((m & 3) << 1 | (m >> 2)) << 13) | (ch << 5) | self.rs
            if not self.ext():
                fa &= 0x3FFF
            e.font = self.planes[2][fa]
            self.c('font_fetch_map%d' % m)
        else:
            e.font = e.planes[2]

    def serial(self, e, w):
        """Index C3..C0 per dot of one fetched character."""
        out = [0] * w
        g5 = self.gc[5]
        sl = bit(self.seq[1], 2)
        for j in range(min(w, 8)):
            v = 0
            if bit(g5, 6):
                by = e.planes[j >> 1]                   # ASSUMPTION V17
                v = (by >> 4) if j % 2 == 0 else (by & 15)
            else:
                for c in range(2):
                    pa, pb = e.planes[2 * c], e.planes[2 * c + 1]
                    if sl:
                        by = pb if e.hcodd else pa       # EGA E19
                        v |= bit(by, 7 - j) << (2 * c)
                    elif bit(g5, 5):
                        by = pa if j < 4 else pb
                        k = j & 3
                        v |= (bit(by, 7 - 2 * k) << (2 * c + 1)) | (bit(by, 6 - 2 * k) << (2 * c))
                    else:
                        v |= (bit(pa, 7 - j) << (2 * c)) | (bit(pb, 7 - j) << (2 * c + 1))
            out[j] = v
        return out                                      # EGA E32: 9th dot 0

    def form(self, e, cur, w):
        am = self.areg[0x10]
        low = self.serial(e, w) if e.gcgraph else [e.planes[1] & 15] * w
        glyph = e.font
        blink_en = bit(am, 3)
        blink_off = bit(self.blink, 4)
        idx = [0] * w
        for j in range(w):
            at = (e.planes[1] & 0xF0) | low[j]
            if bit(am, 0):
                v = at & 15
                if blink_en and blink_off:
                    v |= 8                              # EGA E20
                idx[j] = v
                continue
            if j < 8:
                g = bit(glyph, 7 - j)
            else:
                lg = (e.planes[0] & 0xE0) == 0xC0
                g = bit(glyph, 0) if (bit(am, 2) and lg) else 0     # p.2-93
            fg = at & 15
            bg = ((at >> 4) & 7) if blink_en else (at >> 4)
            if bit(am, 1) and e.ul and (at & 0x77) == 0x01:
                g = 1                                   # EGA E22
            if blink_en and bit(at, 7) and blink_off:
                g = 0
            if cur and not bit(self.blink, 3):
                g = 1                                   # EGA E23
            idx[j] = fg if g else bg
        return idx

    def boundary(self):
        self.wchar = self.wnew()
        e = self.crtc_flags()
        self.fetch(e)
        self.hist = self.hist[1:] + [e]                 # hist[7] = k, hist[7-d] = k-d
        vs_now = self.vsl                               # vertical retrace of k
        if self.reset_drv:
            self.crtc_reset()
        else:
            self.crtc_step()
        if self.vstart:
            self.blink = (self.blink + 1) & 31
        # p.2-92: panning compatibility
        if self.vstart:
            self.pan_lc = 0
        elif self.lchit and bit(self.areg[0x10], 5):
            self.pan_lc = 1
            self.c('pan_compat_hit')
        h = self.hist
        r = self.crtc
        skew = (r[3] >> 5) & 3
        cskew = (r[0xB] >> 5) & 3
        hdel = (r[5] >> 5) & 3
        text = not bit(self.gc[6], 0)
        base = 3 if text else 2                         # ASSUMPTION V14
        am = self.areg[0x10]
        E, N = h[7 - base], h[8 - base]
        cur_e = h[7 - base - cskew].cursor and not am & 1
        cur_n = h[8 - base - cskew].cursor and not am & 1
        self.cur = (E, cur_e)
        self.nxt = (N, cur_n)
        self.cur_idx = self.nxt_idx = None
        self.de_out = h[7 - base - skew].de
        self.blank_out = h[6 - base].blank
        en = bit(r[0x17], 7)
        self.hs_out = (self.hs if hdel == 0 else h[7 - hdel].hs) & en
        self.vs_out = vs_now & en
        self.c('skew_%d' % skew)
        self.c('cskew_%d' % cskew)
        self.c('hdelay_%d' % hdel)
        self.c('pipe_%s' % ('text' if text else 'gfx'))
        if E.de:
            self.c('amode_%s' % ('gfx' if am & 1 else 'text'))
            for b in (0, 1, 2, 3, 5, 6, 7):
                if bit(am, b):
                    self.c('amode_bit%d' % b)
            if cur_e:
                self.c('cursor_char')
            if E.ul and bit(am, 1) and not am & 1:
                self.c('underline_row')
            self.c('gc_shift%d_sl%d_c256_%d' % (bit(self.gc[5], 5), bit(self.seq[1], 2),
                                                bit(self.gc[5], 6)))
            self.c('clock_w%d_div%d' % (self.wchar, bit(self.seq[1], 3)))
        if not self.fast:
            # the attribute controller forms both characters at the boundary
            self.cur_idx = self.form(E, cur_e, self.wchar)
            self.nxt_idx = self.form(N, cur_n, self.wchar)

    def idx_at(self, s):
        w = self.wchar
        if s < w:
            if self.cur_idx is None:
                self.cur_idx = self.form(self.cur[0], self.cur[1], w)
            return self.cur_idx[s]
        if self.nxt_idx is None:
            self.nxt_idx = self.form(self.nxt[0], self.nxt[1], w)
        return self.nxt_idx[s - w]

    def dac_address(self, j):
        w = self.wchar
        pan = 0 if self.pan_lc else self.areg[0x13]
        if w == 9:
            sh = 0 if pan >= 8 else pan + 1              # Figure 2-88 / EGA E24
        else:
            sh = pan & 7
        if pan and not self.fast:
            self.c('pan_%d_w%d' % (pan, w))
        s = j + sh
        am = self.areg[0x10]
        cpe = self.areg[0x12] & 15
        if not self.de_out or not self.attr_idx & 0x20:
            return self.areg[0x11]                      # overscan (EGA E27)
        if bit(am, 6):
            # ASSUMPTION V18: pairs (0,1), (2,3) of the panned stream
            p0 = self.pal[self.idx_at(s & ~1) & cpe]
            p1 = self.pal[self.idx_at(s | 1) & cpe]
            return ((p0 & 15) << 4) | (p1 & 15)
        p = self.pal[self.idx_at(s) & cpe]
        cs = self.areg[0x14]
        p54 = (cs & 3) if bit(am, 7) else (p >> 4)
        return ((cs >> 2) << 6) | (p54 << 4) | (p & 15)

    def dot(self, j):
        blank = self.blank_out or bit(self.seq[1], 5)    # p.2-49 screen off
        if blank:
            rgb = (0, 0, 0)
        else:
            rgb = self.dac[self.dac_address(j) & self.pelmask]   # ASSUMPTION V19
        self.rgb = rgb
        hs = self.hs_out ^ bit(self.misc, 6)
        vs = self.vs_out ^ bit(self.misc, 7)
        return (rgb[0] | (rgb[1] << 6) | (rgb[2] << 12) | (hs << 18) | (vs << 19)
                | (blank << 20) | (self.de_out << 21))

    def fast_rgb(self):
        blank = self.blank_out or bit(self.seq[1], 5)
        if blank:
            return (0, 0, 0)
        return self.dac[self.dac_address(self.last_j) & self.pelmask]

    def pulse(self):
        """One master pulse of the selected oscillator (bench T command)."""
        if self.reset_drv:
            self.crtc_reset()
        if (self.misc >> 2) & 3 == 3 or not self.running():
            return                                      # reserved clock / halted
        if (self.misc >> 2) & 3 == 2:
            return                                      # external clock tied off
        if bit(self.seq[1], 3):
            d = self.half == 0
            self.half ^= 1
            if not d:
                return
        else:
            self.half = 0
        if self.dotcnt == 0:
            self.boundary()
        if self.fast:
            self.last_j = self.dotcnt
            self.ndots += 1
        else:
            self.out.append(self.dot(self.dotcnt))
        self.dotcnt += 1
        if self.dotcnt >= self.wchar:
            self.dotcnt = 0

    ndots = 0

    # ------------------------------------------------------- pins/debug
    def set_reset_drv(self, v):
        self.reset_drv = v
        if v:
            self.misc = 0                               # ASSUMPTION V2
            self.vse = 0
            self.pos102 = 0
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
        if 0x30 <= a <= 0x38:
            return self.gc[a - 0x30]
        if a == 0x39:
            return self.gc_idx
        if 0x40 <= a <= 0x4F:
            return self.pal[a - 0x40]
        if 0x50 <= a <= 0x54:
            return self.areg[a - 0x40]
        tbl = {0x55: self.attr_idx, 0x56: self.attr_ff, 0x60: self.misc, 0x61: self.fcr,
               0x67: self.intlatch, 0x68: self.blink, 0x69: self.vse, 0x6A: self.pos102,
               0x70: self.pelmask, 0x71: self.dac_addr, 0x72: self.dac_sub,
               0x73: self.dac_rmode, 0x74: self.dac_hold[0], 0x75: self.dac_hold[1],
               0x76: self.sense()}
        if 0x62 <= a <= 0x65:
            return self.latch[a - 0x62]
        return tbl.get(a, 0xFF)


DBG_REGS = (list(range(0, 6)) + list(range(0x10, 0x2A)) + list(range(0x30, 0x3A))
            + list(range(0x40, 0x57)) + list(range(0x60, 0x66)) + [0x67, 0x68, 0x69, 0x6A]
            + list(range(0x70, 0x77)))


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
    m = VGA(rom)
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
                lines.append('V %d %06x' % (c, v))
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
        elif op == 'LOAD':
            m.load = h[0] & 7
        elif op == 'DACK':
            m.dack0_n = h[0] & 1
        elif op == 'DUMPR':
            lines.append('D ' + ' '.join('%02x' % m.dbg_reg(a) for a in DBG_REGS))
        elif op == 'DUMPM':
            p, a0, n = h
            lines.append('M %d %04x ' % (p, a0) + ''.join(
                '%02x' % m.planes[p][(a0 + i) & 0xFFFF] for i in range(n)))
        elif op == 'DUMPDAC':
            lines.append('C ' + ' '.join('%05x' % ((r << 12) | (g << 6) | b) for r, g, b in m.dac))
        elif op == 'XREG':
            lines.append('Q R %02x %02x' % (h[0], m.dbg_reg(h[0])))
            expect(m.dbg_reg(h[0]), h[1], 'XREG %02x' % h[0])
        elif op == 'XMEM':
            lines.append('Q M %d %04x %02x' % (h[0], h[1], m.planes[h[0]][h[1]]))
            expect(m.planes[h[0]][h[1]], h[2], 'XMEM %d %04x' % (h[0], h[1]))
        elif op == 'XDAC':
            r, g, b = m.dac[h[0]]
            v = (r << 12) | (g << 6) | b
            lines.append('Q C %02x %05x' % (h[0], v))
            expect(v, h[1], 'XDAC %02x' % h[0])
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
