#!/usr/bin/env python3
"""Directed tests for the IBM PS/2 Display Adapter with expected values
derived by hand from the IBM documents (HITR "Video Subsystem (Type 1)",
VGAXGA "VGA Function", cited per test) and the spec ledger.

usage: directed_tests.py OUTDIR

Writes OUTDIR/<name>.txt bench scripts and OUTDIR/list.txt. Every literal
expectation (OR/MR value, XREG, XMEM, XDAC, XPIX, XDOTS, XIRQ) was worked
out from the register descriptions cited in the comments; video
expectations come from tiny_counter()/expect_dot() below, a direct
closed-form statement of the CRTC rules of spec "CRTC timing" for the tiny
geometry (not the model's step-by-step code). run_sim.sh runs each script
on the model (which must meet every expectation) and on the RTL (whose
trace must equal the model's, including the observed value at every
expectation point).

Tiny geometry (8-dot characters, 25.175 MHz, no /2): HT=2 -> 7 characters
per line (p.2-56: total - 5); HDE=2 -> characters 0-2; SHB=3, EHB=06h ->
blank characters 3-5; SHR=4, EHR=05h -> retrace character 4 (the line
counter advances there, EGA E13); VT=5 -> 7 lines (p.2-61: total - 2);
VDE=2 -> lines 0-2; VBS=3, VBE=05h -> blank lines 3-4; VRS=4, VRE=25h ->
retrace line 4; Line Compare 3FFh (never); byte mode, CMS0/SRC off (Mode
Control E3h); Offset 2 -> 4 bytes per row; MSL 0. Pipeline (ASSUMPTION
V14, graphics): data and DE of counter character k appear at output
character k+2, blank at k+3, horizontal retrace at k (delay 0), vertical
retrace at k.
"""
import os
import sys

TESTS = []


def test(fn):
    TESTS.append(fn)
    return fn


class S:
    def __init__(self):
        self.l = []

    def __call__(self, *lines):
        self.l.extend(lines)
        return self

    def ow(self, p, v):
        return self('OW %03x %02x' % (p, v))

    def seq(self, i, v):
        return self.ow(0x3C4, i).ow(0x3C5, v)

    def crtc(self, i, v, base=0x3D4):
        return self.ow(base, i).ow(base + 1, v)

    def gc(self, i, v):
        return self.ow(0x3CE, i).ow(0x3CF, v)

    def attr(self, i, v, st=0x3DA):
        # index with IPAS = 0, data, then IPAS = 1 again (p.2-90)
        return self('OR %03x' % st).ow(0x3C0, i).ow(0x3C0, v).ow(0x3C0, 0x20)

    def dac(self, i, r, g, b):
        return self.ow(0x3C8, i).ow(0x3C9, r).ow(0x3C9, g).ow(0x3C9, b)

    def mw(self, a, v):
        return self('MW %05x %02x' % (a, v))

    def text(self):
        return '\n'.join(self.l) + '\n'


def enable(s):
    """POST sequence C000:0096-00AA as byte cycles (spec V4)."""
    return s('OW 46e8 16', 'OW 46e9 00', 'OW 102 01', 'OW 103 00', 'OW 46e8 0e', 'OW 46e9 00')


TINY_CRTC = [0x02, 0x02, 0x03, 0x06, 0x04, 0x05, 0x05, 0x10, 0x00, 0x40,
             0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x25, 0x02, 0x02,
             0x00, 0x03, 0x05, 0xE3, 0xFF]
CPL = 7          # characters per line
LPF = 7          # lines per frame
FRAME = 8 * CPL * LPF


def tiny(s, crtc=None, amode=0x01, misc=0x03, seq1=0x01, seq4=0x06, gcmisc=0x05, gcmode=0x00,
         pelmask=0xFF):
    """Enable the card and program the tiny geometry (sequencer halted)."""
    enable(s)
    s.seq(0, 0x01).seq(1, seq1).seq(2, 0x0F).seq(3, 0x00).seq(4, seq4)
    s.ow(0x3C2, misc)
    for i, v in enumerate(TINY_CRTC if crtc is None else crtc):
        s.crtc(i, v)
    s.gc(5, gcmode).gc(6, gcmisc).gc(8, 0xFF)          # bit mask (V1: power-on 00h)
    for i in range(16):
        s.attr(i, i)
    s.attr(0x10, amode).attr(0x11, 0x00).attr(0x12, 0x0F).attr(0x13, 0x00).attr(0x14, 0x00)
    s('OR 3da').ow(0x3C0, 0x20)
    s.ow(0x3C6, pelmask)
    return s


def run_seq(s):
    return s.seq(0, 0x03)


def tiny_counter(k):
    """CRTC state at boundary k (k = 0 is the first after the sequencer
    starts from its reset state): hc, vc and the memory address."""
    hc = k % CPL
    adv = (k + CPL - 1 - 4) // CPL           # boundaries j < k with j % 7 == 4
    vc = adv % LPF
    line_start = k - hc                       # boundary of hc = 0 of this counter line
    adv0 = (line_start + CPL - 1 - 4) // CPL  # advances before hc = 0
    row = adv0 % LPF                          # advances in this frame before hc = 0
    ma = 4 * row + hc
    return hc, vc, ma


def flags(k):
    hc, vc, ma = tiny_counter(k)
    return {'de': hc <= 2 and vc <= 2, 'hb': 3 <= hc <= 5, 'vb': vc in (3, 4),
            'hs': hc == 4, 'vs': vc == 4, 'ma': ma}


def rgbv(r, g, b):
    return r | (g << 6) | (b << 12)


def dot_index(k, j=0):
    return 8 * k + j


DE_BIT, BL_BIT, HS_BIT, VS_BIT = 1 << 21, 1 << 20, 1 << 18, 1 << 19


# ------------------------------------------------------------------ tests
@test
def power_on(s):
    # V1: registers clear; V2/V4: the card is disabled, so no 3xx port and
    # no RAM decodes, while the ROM (V22) reads 55 AA 30 at C0000h
    s('XREG 60 00', 'XREG 69 00', 'XREG 6a 00', 'XREG 70 00', 'XREG 00 00', 'XREG 10 00')
    s('OR 3c2 Z', 'OR 3cc Z', 'OR 3da Z', 'OR 3c9 Z', 'OR 46e8 Z', 'OR 102 Z')
    s('MR c0000 55', 'MR c0001 aa', 'MR c0002 30', 'MR c6000 00', 'MR c7fff 00', 'MR c8000 Z')
    s('MR a0000 Z', 'MR b8000 Z')


@test
def card_enable(s):
    # HITR p.10 / spec V4: enable = 46E8h bit 3 AND POS 102h bit 0
    s('OW 46e8 08', 'OR 3cc Z')                       # POS still 0
    s('OW 102 01', 'XREG 6a 00')                     # not in setup: ignored
    s('OW 46e8 18', 'OR 102 00', 'OW 102 01', 'OR 102 01', 'OR 3c9 Z', 'OR 3c6 Z')
    s('OR 3cc 00')                                   # enabled, in setup: 3xx decoded
    s('OW 46e8 08', 'OR 102 Z', 'OR 3cc 00', 'OR 3c6 00', 'OR 46e8 Z')
    s('OW 3c2 67', 'OR 3cc 67', 'OR 3c3 Z', 'OW 3c3 01', 'XREG 60 67')
    s('OW 46e8 00', 'OR 3cc Z', 'OW 3c2 00', 'XREG 60 67')   # disabled: write ignored
    s('MR c0000 55', 'OW 46e8 0e', 'OR 3cc 67', 'XREG 69 0e', 'XREG 6a 01')


@test
def io_decode_aliases(s):
    enable(s)
    # A9-A0 decode (V3): 7C4h reaches the sequencer index, 0BCCh Misc read
    s.ow(0x7C4, 0x02).ow(0x3C5, 0x05)
    s('XREG 02 05', 'XREG 05 02')
    s('OW 3c2 01', 'OR 0bcc 01')
    # 3Dx with Misc bit 0 = 1, 3Bx not decoded; then the reverse (p.2-43)
    s.ow(0x3D4, 0x0C).ow(0x3D5, 0x12)
    s('OR 3d5 12', 'OR 3b5 Z', 'OR 3ba Z')
    s('OW 3c2 00', 'OR 3d5 Z', 'OR 3b4 0c', 'OR 3b5 12')
    # AEN high ignored; 46E8h exact 16-bit decode (2E8h, 6E8h are not it)
    s('OWN 3b5 34', 'OR 3b5 12', 'ORN 3b5 Z')
    s('OW 2e8 00', 'OW 06e8 00', 'OR 3cc 00', 'XREG 69 0e')


@test
def registers_readback(s):
    enable(s)
    s('OW 3c2 e3', 'OR 3cc e3', 'OW 3da 5a', 'OR 3ca 5a')
    # sequencer (Figures 2-29 to 2-36): stored bits only (V7)
    s.ow(0x3C4, 0xFF)
    s('OR 3c4 07')
    for i, m in enumerate([0x03, 0x3D, 0x0F, 0x3F, 0x0E]):
        s.ow(0x3C4, i).ow(0x3C5, 0xFF)
        s('OR 3c5 %02x' % m)
    s.ow(0x3C4, 0x05)
    s('OR 3c5 00')
    s.seq(0, 0x03)
    # CRTC (Figures 2-39 to 2-66): 8 bits except 08h, 0Ah, 0Bh, 14h, 17h
    s.crtc(0x11, 0x00)
    s.ow(0x3D4, 0xFF)
    s('OR 3d4 1f', 'OR 3d5 00')                     # reserved index (V7)
    masks = {0x08: 0x7F, 0x0A: 0x3F, 0x0B: 0x7F, 0x14: 0x7F, 0x17: 0xEF, 0x11: 0x7F}
    for i in range(25):
        v = 0x7F if i == 0x11 else 0xFF
        s.crtc(i, v)
        s('OR 3d5 %02x' % masks.get(i, 0xFF))
    s.crtc(0x11, 0x00)
    # graphics (Figures 2-68 to 2-80)
    s.ow(0x3CE, 0xFF)
    s('OR 3ce 0f')
    for i, m in enumerate([0x0F, 0x0F, 0x0F, 0x1F, 0x03, 0x7B, 0x0F, 0x0F, 0xFF]):
        s.gc(i, 0xFF)
        s('OR 3cf %02x' % m)
    # attribute: 3C0 write / 3C0 read address / 3C1 read data (p.2-89)
    s('OR 3da')
    for i, m in [(0x00, 0x3F), (0x0F, 0x3F), (0x10, 0xEF), (0x11, 0xFF), (0x12, 0x3F),
                 (0x13, 0x0F), (0x14, 0x0F), (0x15, 0x00)]:
        s.ow(0x3C0, i).ow(0x3C0, 0xFF)
        s('OR 3c0 %02x' % i, 'OR 3c1 %02x' % m)
    s.ow(0x3C0, 0x3F)
    s('OR 3c0 3f', 'XREG 56 01')


@test
def crtc_protect(s):
    # p.2-70: Protect blocks 00-07 except Overflow bit 4 (LC8)
    enable(s)
    s('OW 3c2 01')
    s.crtc(0x00, 0x5F).crtc(0x07, 0x00).crtc(0x11, 0x80)
    s.crtc(0x00, 0x11).crtc(0x06, 0x22).crtc(0x07, 0xFF).crtc(0x08, 0x05)
    s('XREG 10 5f', 'XREG 16 00', 'XREG 17 10', 'XREG 18 05')
    s.crtc(0x11, 0x00).crtc(0x00, 0x11)
    s('XREG 10 11')


@test
def attribute_flipflop(s):
    enable(s)
    s('OW 3c2 01')
    # p.2-89: writes to 3C0 toggle; reads of 3C0/3C1 do not; ISR1 read resets
    s('OR 3da', 'XREG 56 00')
    s.ow(0x3C0, 0x05)
    s('XREG 56 01', 'OR 3c0 05', 'OR 3c1 00', 'XREG 56 01')
    s.ow(0x3C1, 0x2A)                                 # V6: not decoded
    s('XREG 56 01', 'XREG 45 00')
    s.ow(0x3C0, 0x2A)
    s('XREG 56 00', 'XREG 45 2a')
    # IPAS = 1: palette writes ignored (EGA E27), readback still the register
    s.ow(0x3C0, 0x25).ow(0x3C0, 0x11)
    s('XREG 45 2a', 'OR 3c1 2a', 'XREG 55 25')
    s.ow(0x3C0, 0x12)
    s('OR 3da', 'XREG 56 00')


@test
def dac_state_machine(s):
    enable(s)
    # p.2-105: write 3C8, three data writes (R, G, B; 6 bits), increment
    s.ow(0x3C8, 0x10).ow(0x3C9, 0xFF).ow(0x3C9, 0x21).ow(0x3C9, 0x0F)
    s('XDAC 10 3f84f', 'OR 3c8 11', 'OR 3c7 00', 'XREG 72 00')
    s.ow(0x3C9, 0x01).ow(0x3C9, 0x02)
    s('XREG 72 02', 'XREG 74 01', 'XREG 75 02', 'XDAC 11 00000')
    s.ow(0x3C8, 0x11)                                  # restart: cycle terminated
    s('XREG 72 00', 'XDAC 11 00000')
    # read: 3C7, three reads, increment; DAC state 03h
    s.ow(0x3C7, 0x10)
    s('OR 3c7 03', 'OR 3c9 3f', 'OR 3c9 21', 'OR 3c9 0f', 'OR 3c8 11', 'OR 3c9 00')
    # V20: a write in read mode uses the shared sub-index and address
    s.ow(0x3C7, 0x20)
    s('OR 3c9 00')
    # the read left sub-index 1: the writes complete the triple with the
    # stale holding red (01h from above), writing entry 20h = (01, 05, 06)
    s.ow(0x3C9, 0x05).ow(0x3C9, 0x06)
    s('XDAC 20 01146', 'XDAC 21 00000', 'OR 3c8 21', 'XREG 72 00')
    s.ow(0x3C8, 0xFF).ow(0x3C9, 1).ow(0x3C9, 2).ow(0x3C9, 3)
    s('XDAC ff 01083', 'OR 3c8 00')
    # setup mode: the DAC is not decoded (HITR p.10)
    s('OW 46e8 1e', 'OR 3c8 Z', 'OW 3c8 40', 'OW 46e8 0e', 'OR 3c8 00')


@test
def write_modes(s):
    enable(s)
    s('OW 3c2 03').seq(2, 0x0F).seq(4, 0x06).gc(6, 0x05).gc(8, 0xFF)
    # latches = 0F/F0/AA/55
    for p, v in enumerate([0x0F, 0xF0, 0xAA, 0x55]):
        s.seq(2, 1 << p)
        s.mw(0xA0000, v)
    s.seq(2, 0x0F)
    s('MR a0000')
    # write mode 0, rotate 3 right, XOR, bit mask F0h, set/reset map 1 = 1
    s.gc(0, 0x02).gc(1, 0x02).gc(3, 0x1B).gc(8, 0xF0).gc(5, 0x00)
    s.mw(0xA0001, 0x81)          # rotate right 3: 81h -> 30h
    # map0: 30^0F=3F -> mask F0: 30|0F = 3F; map1: FF^F0=0F -> 00|00... see below
    # map n: v = (n set/reset enabled ? 8xSR : 30h) XOR latch; out = (v & F0) | (latch & 0F)
    s('XMEM 0 0001 3f', 'XMEM 1 0001 00', 'XMEM 2 0001 9a', 'XMEM 3 0001 65')
    # write mode 1: latches
    s.gc(5, 0x01)
    s.mw(0xA0002, 0x00)
    s('XMEM 0 0002 0f', 'XMEM 1 0002 f0', 'XMEM 2 0002 aa', 'XMEM 3 0002 55')
    # write mode 2: 8 x data bit n, function none, bit mask 3Ch
    s.gc(3, 0x00).gc(8, 0x3C).gc(5, 0x02)
    s.mw(0xA0003, 0x05)          # maps 0, 2 = FF, maps 1, 3 = 00
    s('XMEM 0 0003 3f', 'XMEM 1 0003 c0', 'XMEM 2 0003 be', 'XMEM 3 0003 41')
    # write mode 3 (p.2-85): 8 x set/reset, mask = bit mask & rotated data
    s.gc(0, 0x05).gc(1, 0x00).gc(3, 0x01).gc(8, 0xF0).gc(5, 0x03)
    s.mw(0xA0004, 0x3C)          # rotate 1: 1Eh; mask F0 & 1E = 10h
    s('XMEM 0 0004 1f', 'XMEM 1 0004 e0', 'XMEM 2 0004 ba', 'XMEM 3 0004 45')


@test
def read_modes(s):
    enable(s)
    s('OW 3c2 03').seq(4, 0x06).gc(6, 0x05).gc(8, 0xFF)
    for p, v in enumerate([0x0F, 0x33, 0x55, 0xFF]):
        s.seq(2, 1 << p)
        s.mw(0xA0010, v)
    for m, v in enumerate([0x0F, 0x33, 0x55, 0xFF]):
        s.gc(4, m)
        s('MR a0010 %02x' % v)
    # read mode 1 (p.2-81, p.2-87): compare 0101b on maps with don't care 1
    s.gc(5, 0x08).gc(2, 0x05).gc(7, 0x0F)
    # bit b = (m0==1)&(m1==0)&(m2==1)&(m3==0): m3 = FF -> never
    s('MR a0010 00')
    s.gc(7, 0x07)                # ignore map 3: m0=1,m1=0,m2=1 -> 0F&CC&55 = 04
    s('MR a0010 04')
    s.gc(7, 0x00)
    s('MR a0010 ff')
    s('XREG 62 0f', 'XREG 63 33', 'XREG 64 55', 'XREG 65 ff')


@test
def odd_even_and_chain4(s):
    enable(s)
    # odd/even (Memory Mode bit 2 = 0, GC Mode bit 4, GC Misc bit 1 chain)
    s('OW 3c2 23').seq(2, 0x0F).seq(4, 0x02).gc(5, 0x10).gc(6, 0x0E).gc(8, 0xFF)
    s.mw(0xB8000, 0x41).mw(0xB8001, 0x1F).mw(0xB8002, 0x42)
    # page bit (Misc 5) = 1 -> plane address bit 0 = 0 (V13); A0 -> map
    s('XMEM 0 0000 41', 'XMEM 1 0000 1f', 'XMEM 0 0002 42', 'XMEM 2 0000 41', 'XMEM 3 0000 1f')
    s.gc(4, 0x00)
    s('MR b8001 1f', 'MR b8000 41')
    s.gc(4, 0x02)
    s('MR b8000 41', 'MR b8003 00')
    # chain 4 (p.2-54 Figure 2-37): A1-A0 select the map; V15 plane address
    s('OW 3c2 63').seq(4, 0x0E).gc(5, 0x40).gc(6, 0x05)
    for o, v in [(0x0000, 0x10), (0x0001, 0x11), (0x0002, 0x12), (0x0007, 0x17),
                 (0x4005, 0x45), (0xFFFE, 0xFE)]:
        s.mw(0xA0000 + o, v)
    s('XMEM 0 0000 10', 'XMEM 1 0000 11', 'XMEM 2 0000 12', 'XMEM 3 0004 17')
    s('XMEM 1 4005 45', 'XMEM 2 ffff fe')
    s('MR a0007 17', 'MR a4005 45', 'MR affff 00', 'MR afffe fe')
    # without extended memory the plane address is limited to 16 KB
    s.seq(4, 0x0C)
    s.mw(0xA4006, 0x66)          # plane address {4006h[15:2], 01} & 3FFFh = 0005h
    s('XMEM 2 0005 66', 'XMEM 2 4005 00')


@test
def memory_maps(s):
    enable(s)
    s('OW 3c2 03').seq(2, 0x01).seq(4, 0x06).gc(8, 0xFF)
    for m, (a, ok) in enumerate([(0xB0000, True), (0xA0000, True), (0xB0000, True), (0xB8000, True)]):
        s.gc(6, (m << 2) | 1)
        s.mw(a + 0x10 + m, 0x80 + m)
    s('XMEM 0 0010 80', 'XMEM 0 0011 81', 'XMEM 0 0012 82', 'XMEM 0 0013 83')
    s.gc(6, 0x09)                                      # B0000h 32 KB
    s('MR b0012 82', 'MR b8013 Z', 'MR a0011 Z')
    s.gc(6, 0x01)                                      # 128 KB map, A16 -> plane address
    s('MR b0010 80', 'MR a0010 80')
    s('OW 3c2 01', 'MR a0010 Z', 'DACK 0', 'MR c0000 Z', 'DACK 1', 'MR c0000 55')


@test
def tiny_frame_timing(s):
    tiny(s)
    s.dac(0, 0x00, 0x00, 0x00).dac(1, 0x3F, 0x00, 0x00)
    run_seq(s)
    s('T %d' % (8 * CPL * LPF * 2))
    s('XDOTS %d' % (8 * CPL * LPF * 2))
    # every dot of two frames from the closed-form counter (no memory: index 0)
    for k in range(CPL * LPF * 2):
        de = flags(k - 2)['de'] if k >= 2 else False
        bl = (flags(k - 3)['hb'] or flags(k - 3)['vb']) if k >= 3 else False
        f = flags(k)
        want = (DE_BIT if de else 0) | (BL_BIT if bl else 0) | (HS_BIT if f['hs'] else 0) | \
            (VS_BIT if f['vs'] else 0)
        s('XPIX %d 3c0000 %06x' % (dot_index(k, 3), want))


@test
def graphics_pixels(s):
    tiny(s)
    # planar 16 colours (p.2-22): map n = C(n); palette identity; DAC n
    for n in range(16):
        s.dac(n, n, 2 * n & 0x3F, 0x3F - n)
    s.seq(2, 0x01).mw(0xA0000, 0xF0).seq(2, 0x02).mw(0xA0000, 0xCC)
    s.seq(2, 0x04).mw(0xA0001, 0xFF).seq(2, 0x08).mw(0xA0004, 0x81).seq(2, 0x0F)
    run_seq(s)
    s('T %d' % (8 * CPL * LPF))
    # output char 2 = counter char 0 (ma 0): bits map0 F0, map1 CC -> dots 0-7
    for j, c in enumerate([3, 3, 1, 1, 2, 2, 0, 0]):
        s('XPIX %d 03ffff %06x' % (dot_index(2, j), rgbv(c, 2 * c, 0x3F - c)))
    # output char 3 = ma 1: map 2 = FF -> colour 4
    s('XPIX %d 03ffff %06x' % (dot_index(3, 5), rgbv(4, 8, 0x3B)))
    # output char 9 = counter 7 (next line, row 1: ma 4): map 3 = 81h
    s('XPIX %d 03ffff %06x' % (dot_index(9, 0), rgbv(8, 16, 0x37)))
    s('XPIX %d 03ffff %06x' % (dot_index(9, 1), rgbv(0, 0, 0x3F)))


@test
def color_plane_enable_and_select(s):
    tiny(s)
    s.seq(2, 0x0F).mw(0xA0000, 0xFF)                    # index 15 everywhere in char 0
    s.attr(0x0F, 0x35)
    for a, rgb in [(0x35, (1, 2, 3)), (0x05, (4, 5, 6)), (0xF5, (7, 8, 9)), (0xE5, (10, 11, 12)),
                   (0x07, (13, 14, 15))]:
        s.dac(a, *rgb)
    s.attr(0x12, 0x0F)
    run_seq(s)
    # every T is one whole frame, so dot 16 is always line 0, character 2
    s('T %d' % FRAME, 'XPIX 16 03ffff %06x' % rgbv(1, 2, 3))
    # P7-P6 from Color Select 3-2 (p.2-96): 0Ch -> F5 with P5P4 = 11
    s.seq(0, 1).attr(0x14, 0x0C).seq(0, 3)
    s('T %d' % FRAME, 'XPIX 16 03ffff %06x' % rgbv(7, 8, 9))
    # Attribute Mode bit 7: P5-P4 from Color Select 1-0 (= 10b) -> E5
    s.seq(0, 1).attr(0x14, 0x0E).attr(0x10, 0x81).seq(0, 3)
    s('T %d' % FRAME, 'XPIX 16 03ffff %06x' % rgbv(10, 11, 12))
    # Color Plane Enable 07h: index 15 -> 7, palette 7 = 07h
    s.seq(0, 1).attr(0x14, 0x00).attr(0x10, 0x01).attr(0x12, 0x07).seq(0, 3)
    s('T %d' % FRAME, 'XPIX 16 03ffff %06x' % rgbv(13, 14, 15))


@test
def dac_pel_mask(s):
    tiny(s, pelmask=0x03)
    s.seq(2, 0x0F).mw(0xA0000, 0xFF)
    s.dac(0x0F, 1, 1, 1).dac(0x03, 0x22, 0x23, 0x24)
    run_seq(s)
    s('T 40', 'XPIX 16 03ffff %06x' % rgbv(0x22, 0x23, 0x24))
    s.ow(0x3C6, 0xFF)
    # the second T starts at boundary 5: boundary 51 (frame 2, line 0, char 2)
    s('T 600', 'XPIX %d 03ffff %06x' % (dot_index(51 - 5 - 2 + 2), rgbv(1, 1, 1)))


@test
def overscan_and_screen_off(s):
    tiny(s)
    s.attr(0x11, 0x9A).dac(0x9A, 0x10, 0x20, 0x30).dac(0, 0x01, 0x01, 0x01)
    run_seq(s)
    # counter char 3-5 blank, so overscan shows only at output... DE off and
    # not blanked: output char 5 has DE of counter 3 (off) and blank of
    # counter 2 (off) -> overscan 9Ah (8-bit, p.2-94)
    s('T 56', 'XPIX 40 03ffff %06x' % rgbv(0x10, 0x20, 0x30))
    s('XPIX 16 03ffff %06x' % rgbv(1, 1, 1))
    # IPAS = 0 forces the overscan colour in the display area (EGA E27)
    s('OR 3da').ow(0x3C0, 0x00)
    s('T 56', 'XPIX 16 03ffff %06x' % rgbv(0x10, 0x20, 0x30))
    # Screen Off (p.2-49): blanked, syncs continue
    s('OR 3da').ow(0x3C0, 0x20).seq(1, 0x21)
    s('T 56', 'XPIX 16 13ffff 100000', 'XPIX 32 040000 040000')


@test
def mode13_pixels(s):
    # 256 colours: chain 4, GC Mode bit 6, Attribute Mode bit 6 (PEL width)
    tiny(s, amode=0x41, seq4=0x0E, gcmode=0x40)
    s.mw(0xA0000, 0x12).mw(0xA0001, 0x34).mw(0xA0002, 0xAB).mw(0xA0003, 0xFF)
    for a, rgb in [(0x12, (1, 2, 3)), (0x34, (4, 5, 6)), (0xAB, (7, 8, 9)), (0xFF, (10, 11, 12))]:
        s.dac(a, *rgb)
    run_seq(s)
    s('T %d' % (8 * CPL * LPF))
    # V17/V18: each byte gives two dots of the same 8-bit DAC address
    for j, a in enumerate([(1, 2, 3), (1, 2, 3), (4, 5, 6), (4, 5, 6), (7, 8, 9), (7, 8, 9),
                           (10, 11, 12), (10, 11, 12)]):
        s('XPIX %d 03ffff %06x' % (dot_index(2, j), rgbv(*a)))
    # panning 2 (Figure 2-88 mode 13h: 1 PEL): starts with the second byte
    s.seq(0, 1).attr(0x13, 0x02).seq(0, 3)
    s('T %d' % (8 * CPL * LPF), 'XPIX %d 03ffff %06x' % (dot_index(2, 0), rgbv(4, 5, 6)))


@test
def text_glyphs(s):
    # alphanumeric: maps 0/1 code/attribute, map 2 font {table, code, row}
    tiny(s, amode=0x00, gcmisc=0x0E, seq1=0x00, seq4=0x02)
    s.seq(2, 0x04).gc(6, 0x04).gc(5, 0x00).seq(4, 0x06)
    s.mw(0xA0000 + 0x41 * 32, 0x81)                    # 'A' row 0 = 10000001
    s.mw(0xA0000 + 0xC4 * 32, 0x01)                    # line graphics code
    s.seq(4, 0x02).gc(6, 0x0E).gc(5, 0x10).seq(2, 0x03)
    s('OW 3c2 23')
    s.mw(0xB8000, 0x41).mw(0xB8001, 0x1E).mw(0xB8002, 0xC4).mw(0xB8003, 0x1E)
    for n, rgb in [(0x0E, (0x3E, 0x3E, 0)), (0x01, (0, 0, 0x2A))]:
        s.dac(n, *rgb)
    s.attr(0x10, 0x04)                                 # line graphics on
    s.attr(0x13, 0x08)                                 # 9-dot panning 8 = no shift (Figure 2-88)
    run_seq(s)
    s('T 63')
    # 9-dot text, text pipeline: data at output k+3 (V14); dot 0 = glyph bit 7
    fg, bg = rgbv(0x3E, 0x3E, 0), rgbv(0, 0, 0x2A)
    for j, c in enumerate([fg, bg, bg, bg, bg, bg, bg, fg, bg]):
        s('XPIX %d 03ffff %06x' % (9 * 3 + j, c))
    # byte mode: memory address 2 (character C4h) is counter character 2,
    # output character 5; its 9th dot equals the 8th (p.2-93)
    s('XPIX %d 03ffff %06x' % (9 * 5 + 7, fg), 'XPIX %d 03ffff %06x' % (9 * 5 + 8, fg))
    s('XPIX %d 03ffff 000000' % (9 * 4 + 0))        # address 1: code 00h, attribute 00h -> DAC 0


@test
def double_scan(s):
    # MSL bit 7 (p.2-64): the row-scan clock is divided by 2. MSL = 1 and
    # double scan: rows of 2 scans each shown twice -> the row address
    # (Offset 2 -> +4) changes every 4 lines, row scan every 2
    c = list(TINY_CRTC)
    c[0x09] = 0xC1
    c[0x06] = 0x09                                      # 11 lines
    c[0x10] = 0x08
    c[0x11] = 0x29
    c[0x12] = 0x07
    c[0x15] = 0x08
    c[0x16] = 0x0A
    c[0x17] = 0xE3                                      # no row-scan address substitution
    tiny(s, crtc=c)
    for o in range(0, 16, 4):
        s.mw(0xA0000 + o, 0x80 >> (o // 4))
    s.seq(2, 0x0F)
    s.dac(15, 0x3F, 0x3F, 0x3F)
    run_seq(s)
    s('T %d' % (8 * CPL * 11))
    # output char k shows counter char k-2; lines 0-1 rs 0 row 0, 2-3 rs 1
    # row 0 (A14 = rs1 = 0 since SRC... ), 4-5 rs 0 row 1 (ma 4)
    for line, dot, on in [(0, 0, 1), (1, 0, 1), (2, 0, 1), (3, 0, 1), (4, 1, 1), (5, 1, 1), (4, 0, 0)]:
        k = line * CPL + 2 + (0 if line == 0 else 0)
        s('XPIX %d 03ffff %06x' % (dot_index(k, dot), rgbv(0x3F, 0x3F, 0x3F) if on else 0))


@test
def switch_sense(s):
    # POST tables C000:0428/043C/0450/0454/0458 (spec V21): PEL mask 0 so
    # every displayed dot uses DAC entry 0; the sense bit is read during
    # display enable. Expected bits are the ROM's own expectations.
    tiny(s, pelmask=0x00)
    run_seq(s)
    cases = [(7, (0x12, 0x12, 0x12), 1), (7, (0x14, 0x14, 0x14), 1), (7, (0x2D, 0x14, 0x14), 0),
             (7, (0x14, 0x2D, 0x14), 0), (7, (0x14, 0x14, 0x2D), 0), (7, (0x2D, 0x2D, 0x2D), 0),
             (2, (0x12, 0x12, 0x12), 0), (2, (0x04, 0x12, 0x04), 1), (2, (0x1E, 0x12, 0x04), 0),
             (2, (0x04, 0x2D, 0x04), 0), (2, (0x04, 0x16, 0x15), 0), (2, (0x00, 0x00, 0x00), 1),
             (0, (0x12, 0x12, 0x12), 0), (0, (0x04, 0x12, 0x04), 0), (0, (0x04, 0x04, 0x04), 1),
             (0, (0x10, 0x04, 0x04), 0), (0, (0x04, 0x10, 0x04), 0), (0, (0x04, 0x04, 0x10), 0),
             (0, (0x10, 0x10, 0x10), 0)]
    for load, rgb, want in cases:
        s('LOAD %x' % load).dac(0, *rgb)
        # stop inside the displayed area: output char 2 of the first line
        s('T %d' % (8 * CPL * LPF - (8 * CPL * LPF) % (8 * CPL * LPF) + 8 * 2 + 3))
        s('OR 3c2 %02x' % (want << 4))
        s('T %d' % (8 * CPL * LPF - 8 * 2 - 3))


@test
def status_bits(s):
    tiny(s)
    run_seq(s)
    # ISR1 (p.2-45): bit 0 = 1 while display enable is off, bit 3 vertical
    # retrace; others 0 (V16). Stop after output char 2 of line 0 (DE on)
    s('T 19', 'OR 3da 00')
    s('T 24', 'OR 3da 01')                              # output char 5: DE off
    # line 4 (vertical retrace): counter char 4 of line 3 advances to vc 4
    s('T %d' % (8 * (4 * CPL + 1) - 43), 'OR 3da 09')
    s('T %d' % (8 * CPL * 2), 'OR 3da 01')


@test
def video_status_mux(s):
    # V16 (EGA E11): Input Status 1 bits 5-4 from the colour outputs chosen
    # by Color Plane Enable bits 5-4. Index 15 everywhere in character 0,
    # palette 15 = 2Ah = P5..P0 101010b; the read is after dot 18 (output
    # character 2 of line 0, display enable on)
    tiny(s)
    s.seq(2, 0x0F).mw(0xA0000, 0xFF)
    s.attr(0x0F, 0x2A)
    run_seq(s)
    s('T 19', 'OR 3da 00')                              # 00: {P2, P0} = 00
    for cpe, want in [(0x1F, 0x30), (0x2F, 0x20), (0x3F, 0x00)]:
        s.attr(0x12, cpe)
        s('T %d' % FRAME, 'OR 3da %02x' % want)
    # Screen Off does not stop the tap (POST C000:0270 runs with it set)
    s.attr(0x12, 0x2F).seq(1, 0x21)
    s('T %d' % FRAME, 'OR 3da 20')


@test
def vertical_interrupt(s):
    tiny(s)
    s.crtc(0x11, 0x15)                                   # enable (bit5 = 0), clear off
    run_seq(s)
    # bit 4 is the switch sense: 1 with a colour load and black (V21)
    s('T %d' % (8 * (3 * CPL + 4)), 'XIRQ 0', 'OR 3c2 10')
    s('T 16', 'XIRQ 1', 'OR 3c2 90')                     # retrace started at line 4
    s.crtc(0x11, 0x05)                                    # bit 4 = 0 clears (p.2-70)
    s('XIRQ 0')
    s.crtc(0x11, 0x35)                                    # disabled: no interrupt
    s('T %d' % (8 * CPL * LPF), 'XIRQ 0')


@test
def split_screen_and_pan_compat(s):
    c = list(TINY_CRTC)
    c[0x18] = 0x01
    c[0x07] = 0x00
    c[0x09] = 0x00
    c[0x0D] = 0x08                                       # start address 8
    tiny(s, crtc=c, amode=0x21)
    s.seq(2, 0x01).mw(0xA0000, 0x80).mw(0xA0008, 0x40).seq(2, 0x0F)
    s.dac(1, 0x3F, 0, 0)
    s.attr(0x13, 0x01)                                   # pan 1 dot
    run_seq(s)
    # the first frame after reset starts at address 0; the start address is
    # loaded at the frame restart (p.2-63), so check the second frame
    s('T %d' % FRAME, 'T %d' % FRAME)
    # line 0 (ma 8): pixel bit 6 -> dot 1, panned left by 1 -> dot 0
    s('XPIX %d 03ffff %06x' % (dot_index(2, 0), rgbv(0x3F, 0, 0)))
    # line compare 1: line 2 restarts at address 0 (p.2-103) and panning is
    # forced to 0 (p.2-92): bit 7 -> dot 0
    s('XPIX %d 03ffff %06x' % (dot_index(2 * CPL + 2, 0), rgbv(0x3F, 0, 0)))
    s('XPIX %d 03ffff 000000' % dot_index(2 * CPL + 2, 1))


@test
def cursor_off(s):
    tiny(s, amode=0x00, gcmisc=0x0E, seq4=0x02)
    s('OW 3c2 23')
    s.mw(0xB8000, 0x20).mw(0xB8001, 0x07)
    s.dac(7, 0x2A, 0x2A, 0x2A)
    s.crtc(0x0A, 0x00).crtc(0x0B, 0x01).crtc(0x0E, 0x00).crtc(0x0F, 0x00)
    run_seq(s)
    s('T 56', 'XPIX %d 03ffff %06x' % (8 * 3, rgbv(0x2A, 0x2A, 0x2A)))
    s.crtc(0x0A, 0x20)                                    # Cursor Off (p.2-65)
    s('T %d' % (8 * CPL * LPF * 2 - 56), 'T 56', 'XPIX %d 03ffff 000000' % (8 * 3))


@test
def reset_drv(s):
    enable(s)
    s('OW 3c2 e3').crtc(0x0C, 0x12)
    s('RST 1', 'XREG 60 00', 'XREG 69 00', 'XREG 6a 00', 'OR 3cc Z', 'RST 0')
    s('MR c0000 55')
    enable(s)
    s('OR 3d5 Z', 'OW 3c2 01', 'OR 3d5 12')


@test
def sequencer_reset_and_dot_clock(s):
    tiny(s, seq1=0x09)                                  # dot clock /2
    run_seq(s)
    s('T 112', 'XDOTS 56')
    s.seq(0, 0x01)
    s('T 50', 'XDOTS 0')
    s.seq(0, 0x03).seq(1, 0x01)
    s('T 50', 'XDOTS 50')
    s('OW 3c2 0f', 'T 20', 'XDOTS 0')                   # clock select 11: none


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    names = []
    for fn in TESTS:
        s = S()
        fn(s)
        with open(os.path.join(out, fn.__name__ + '.txt'), 'w') as f:
            f.write('# directed test %s\n' % fn.__name__ + s.text())
        names.append(fn.__name__)
    with open(os.path.join(out, 'list.txt'), 'w') as f:
        f.write('\n'.join(names) + '\n')
    print('wrote %d directed tests' % len(names))


if __name__ == '__main__':
    main()
