#!/usr/bin/env python3
"""Directed tests for the IBM EGA with expected values derived by hand from
the IBM technical reference (TR, August 2, 1984) and the spec ledger.

usage: directed_tests.py OUTDIR

Writes OUTDIR/<name>.txt bench scripts and OUTDIR/list.txt. Every literal
expectation (OR/MR value, XREG, XMEM, XPIX, XDOTS, XIRQ) was worked out from
the register descriptions cited in the comments, not by running the model.
run_sim.sh runs each script on the model (which must meet every
expectation) and on the RTL (whose trace must equal the model's).

Conventions used by the video tests ("tiny" geometry, 8-dot characters,
14 MHz, no /2): HT=5 -> 7 characters per line (TR p.25: total - 2);
HDE=2 -> characters 0-2 displayed; SHB=4, EHB=26h -> blank characters 4-5,
display enable skew 1; SHR=5, EHR=06h -> retrace character 5; VT=5 ->
7 lines (ASSUMPTION E8: VT+2); VDE=2 -> lines 0-2; VBS=3, VBE=05h -> blank
lines 3-4; VRS=4, VRE=25h -> retrace line 4 only. Byte mode, CMS0/SRS off
(Mode Control E3h), Offset 2 -> 4 bytes per row, MSL 0 -> one scan line per
row. With the pipeline depths of ASSUMPTION E18 the character fetched at
counter character c of a line appears at output character c+2 of the same
line, and output character 5 carries the retrace. A line is 56 dots.
"""
import os
import sys

TESTS = []


def test(fn):
    TESTS.append(fn)
    return fn


class S:
    """Script builder."""

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
        return self('OR %03x' % st).ow(0x3C0, i).ow(0x3C0, v)

    def mw(self, a, v):
        return self('MW %05x %02x' % (a, v))

    def text(self):
        return '\n'.join(self.l) + '\n'


TINY_CRTC = [0x05, 0x02, 0x04, 0x26, 0x05, 0x06, 0x05, 0x00, 0x00, 0x00,
             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x25, 0x02, 0x02,
             0x1F, 0x03, 0x05, 0xE3, 0xFF]
DOTS_PER_LINE = 56


def tiny(s, crtc=None, attr_mode=0x01, misc=0x03, seq1=0x01, seq4=0x06,
         gcmisc=0x05, gcmode=0x00):
    """Program the tiny geometry (sequencer halted while loading)."""
    s.seq(0, 0x01).seq(1, seq1).seq(2, 0x0F).seq(3, 0x00).seq(4, seq4)
    s.ow(0x3C2, misc)
    c = list(TINY_CRTC if crtc is None else crtc)
    c[0x07] |= 0x10                       # line compare bit 8: never
    for i, v in enumerate(c):
        s.crtc(i, v)
    for i in range(16):
        s.attr(i, i)
    s.attr(0x10, attr_mode).attr(0x11, 0x2A).attr(0x12, 0x0F).attr(0x13, 0x00)
    s('OR 3da').ow(0x3C0, 0x20)           # palette address source = 1
    s.ow(0x3CC, 0).ow(0x3CA, 1)
    for i, v in enumerate([0, 0, 0, 0, 0, gcmode, gcmisc, 0, 0xFF]):
        s.gc(i, v)
    return s


def run_seq(s):
    return s.seq(0, 0x03)


def dot(line, ch, j=0):
    return line * DOTS_PER_LINE + ch * 8 + j


def planes_fill(s, addr, vals, mask_after=0x0F):
    """Write one byte per plane at A0000+addr (sequential mode)."""
    for p, v in enumerate(vals):
        s.seq(2, 1 << p).mw(0xA0000 + addr, v)
    s.seq(2, mask_after)
    return s


# ------------------------------------------------------------ registers
@test
def power_on(s):
    # ASSUMPTION E1: all zero. Misc = 0 -> CRTC/ISR1 at 3Bx (TR p.12).
    s('SW a', 'FEAT 3')
    for a in (0x00, 0x01, 0x10, 0x26, 0x30, 0x3A, 0x3B, 0x40, 0x53, 0x54, 0x55,
              0x60, 0x61, 0x62, 0x66, 0x67, 0x68):
        s('XREG %02x 00' % a)
    # ISR0: bits 3-0 pulled up (E4); clock select 00 reads SW4 = sw_i[3] = 1
    # (E31) -> bit 4; FEAT = 3 -> bits 6-5; no interrupt -> bit 7 = 0.
    s('OR 3c2 7f')
    # ISR1 at 3BA: bits 7-6 = 1, display off -> bit 0 = 1 (E10), LP switch
    # open (pin high) -> bit 2 = 1. 0xC0|4|1 = C5.
    s('OR 3ba c5', 'OR 3da Z')
    s('T 50', 'XDOTS 0')                  # sequencer halted (E1, E6)
    s('XIRQ 0')


@test
def switch_sense(s):
    # TR p.15 bit 4 + ASSUMPTION E31: clock select k reads SW(4-k);
    # sw_i bit n = SW(n+1); 1 = open.
    s('SW 6')                             # SW1 on, SW2 off, SW3 off, SW4 on
    want = {0: 0x0F, 1: 0x1F, 2: 0x1F, 3: 0x0F}   # k=0:SW4 on .. k=3:SW1 on
    for k in range(4):
        s.ow(0x3C2, k << 2)
        s('OR 3c2 %02x' % want[k])
    s('SW 9')
    want = {0: 0x1F, 1: 0x0F, 2: 0x0F, 3: 0x1F}
    for k in range(4):
        s.ow(0x3C2, k << 2)
        s('OR 3c2 %02x' % want[k])


@test
def bios_post_switch_read(s):
    # The POST routine at C000:009B (listing lines 619 ff., disassembled):
    # OUT 3C2,01; then OUT 3C2,0D/09/05/01 and IN 3C2 each; bit 4 of each
    # read is shifted into INFO_3 bits 0,1,2,3. With SW1..SW4 =
    # off,off,off,on (TR p.81: EGA + Color Display 80x25, MDA secondary)
    # INFO_3 must be 0111b = 7 ("MONOC SECONDARY, EGA COLOR, 80X25",
    # listing line 592). sw_i = {SW4,SW3,SW2,SW1} = 0111b.
    s('SW 7')
    s.ow(0x3C2, 0x01)
    for v, want in ((0x0D, 0x1F), (0x09, 0x1F), (0x05, 0x1F), (0x01, 0x0F)):
        s.ow(0x3C2, v)
        s('OR 3c2 %02x' % want)
    # feature-bit read, C000:00CE: OUT 3BA,1 / OUT 3DA,1 (misc bit0 = 1 ->
    # only 3DA decodes); IN 3C2 bits 6-5 = FEAT inputs.
    s('FEAT 2')
    s.ow(0x3BA, 1).ow(0x3DA, 1)
    s('OR 3c2 4f', 'XREG 61 01')


@test
def io_decode_aliases(s):
    # TR p.24: CRTC at 3B4/3B5 (misc bit 0 = 0) or 3D4/3D5. Sheet 4: A15-A10
    # not decoded; U16 needs !AEN & A9 & A8 (P3 normal).
    s.ow(0x3B4, 0x0C).ow(0x3B5, 0x12)
    s('XREG 1c 12')
    s.ow(0x3D4, 0x0C).ow(0x3D5, 0x34)     # colour address while mono: ignored
    s('XREG 1c 12')
    s.ow(0x7B5, 0x56)                     # alias of 3B5 (A10 ignored)
    s('XREG 1c 56')
    s.ow(0xFFB5, 0x57)
    s('XREG 1c 57')
    s('OWN 3b5 99', 'XREG 1c 57')         # AEN high: no decode
    s.ow(0x2B5, 0x58)                     # 2XX with P3 normal: ignored
    s('XREG 1c 57')
    s('P3 0')
    s.ow(0x2B5, 0x59).ow(0x3B5, 0x5A)     # P3 at 2XX: 2B5 decodes, 3B5 not
    s('XREG 1c 59', 'P3 1')
    s.ow(0x3C2, 0x01)                     # colour addressing
    s.ow(0x3D5, 0x5B)
    s('XREG 1c 5b', 'OR 3d5 5b', 'OR 3b5 Z', 'ORN 3d5 Z')
    # write-only and undecoded ports do not drive the bus (E3, E4)
    for p in (0x3C0, 0x3C1, 0x3C4, 0x3C5, 0x3CA, 0x3CC, 0x3CE, 0x3CF, 0x3D4,
              0x3DB, 0x3DC, 0x3C3, 0x3D0, 0x3D8, 0x3D9):
        s('OR %03x Z' % p)


@test
def registers_readback(s):
    # TR p.34-38: 0C-0F read/write; 10/11 read light pen; others write-only.
    s.ow(0x3C2, 0x01)
    for i, v in ((0x0C, 0xA5), (0x0D, 0x5A), (0x0E, 0x3C), (0x0F, 0xC3)):
        s.crtc(i, v)
        s('OR 3d5 %02x' % v)
    s.crtc(0x10, 0x77)                    # Vertical Retrace Start (write)
    s('OR 3d5 00', 'XREG 20 77')          # reads Light Pen High = 0
    s.crtc(0x11, 0x2E)
    s('OR 3d5 00', 'XREG 21 2e')
    for i in (0x00, 0x09, 0x13, 0x17, 0x18, 0x19, 0x1F):
        s.crtc(i, 0x11)
        s('OR 3d5 ff')                    # E4: pull-ups
    s('XREG 29 1f')                        # index register keeps 5 bits
    s.seq(0x07, 0x55).seq(0x02, 0xFF)      # index 7 ignored; map mask 4 bits
    s('XREG 02 0f', 'XREG 05 02')
    s.gc(0x09, 0x55).gc(0x08, 0x81)
    s('XREG 38 81', 'XREG 39 08')
    s.gc(0x05, 0xFF)
    s('XREG 35 3f')                        # mode register: bits 5-0


@test
def attribute_flipflop(s):
    # TR p.56-57: address/data selected by an internal flip-flop, cleared by
    # reading 3BA/3DA, toggled by every write to 3C0.
    s.ow(0x3C2, 0x01)
    s('OR 3da').ow(0x3C0, 0x05).ow(0x3C0, 0x2D)
    s('XREG 45 2d', 'XREG 54 05', 'XREG 55 00')
    s.ow(0x3C0, 0x11)                      # address 11h
    s('XREG 55 01', 'OR 3ba Z', 'XREG 55 01')   # inactive status port: no reset
    s('OR 3da', 'XREG 55 00')              # reset: next write is an address
    s.ow(0x3C0, 0x12).ow(0x3C0, 0x3F)
    s('XREG 52 3f', 'XREG 51 00')
    s('OR 3da').ow(0x3C0, 0x10).ow(0x3C0, 0xFF)
    s('XREG 50 0f')                        # mode control keeps bits 3-0
    s('OR 3da').ow(0x3C0, 0x13).ow(0x3C0, 0xFF)
    s('XREG 53 0f')
    s('OR 3da').ow(0x3C0, 0x14).ow(0x3C0, 0x55)  # index 14h: no register
    s('OR 3da').ow(0x3C0, 0x20).ow(0x3C0, 0x2A)  # PAS = 1: palette not loaded
    s('XREG 40 00', 'XREG 54 20')               # (E27)
    s('OR 3da').ow(0x3C0, 0x00).ow(0x3C0, 0xEA)
    s('XREG 40 2a')                              # 6-bit palette


@test
def bios_dot_test_attribute_writes(s):
    # Escaped defect regression (failure_notes/2026-11-16-ibm-ega-attribute-3c1.md).
    # POST dot test, C000:0401-0446 (listing lines 1307-1318): IN status
    # (flip-flop reset), then the OUT_DX helper (C000:0D15: OUT DX,AH;
    # INC DX; OUT DX,AL) with DX = 3C0: 3C0=0Fh, 3C1=3Fh (palette 0Fh = 3Fh,
    # address bit 5 = 0), then 3C0=32h, 3C1=0Fh (Color Plane Enable = 0Fh,
    # address bit 5 = 1 turns the palette back on); the loop repeats the
    # second pair with 1Fh and 2Fh (video status mux 01, 10) and polls
    # Input Status 1 bits 5-4 for 1s, then 0s. All planes FFh -> index 0Fh.
    tiny(s)
    for a in range(3):
        planes_fill(s, a, [0xFF, 0xFF, 0xFF, 0xFF])
    run_seq(s)
    s('OR 3da').ow(0x3C0, 0x0F).ow(0x3C1, 0x3F).ow(0x3C0, 0x32).ow(0x3C1, 0x0F)
    s('XREG 4f 3f', 'XREG 52 0f', 'XREG 54 32', 'XREG 55 00')
    s('T %d' % (dot(0, 2) + 1))
    # colour 3Fh displayed; mux 00 -> bit 5 = R = 1, bit 4 = B = 1; display
    # on (bit 0 = 0); LP switch open (bit 2 = 1): F4h
    s('OR 3da f4')
    for cpe in (0x1F, 0x2F):
        s.ow(0x3C0, 0x32).ow(0x3C1, cpe)
        s('XREG 52 %02x' % cpe, 'XREG 55 00')
        s('OR 3da f4')                     # mux 01: B', G = 1; mux 10: R', G' = 1
    s('T 24')                             # 41 dots: output char 5 of line 0 is
    s('OR 3da c5')                        # blanked: colour 0 -> diag 00, display off


@test
def sequencer_registers(s):
    # TR p.18-23
    for i, v, want in ((0, 0xFF, 0x03), (1, 0xFF, 0x0F), (2, 0xFF, 0x0F),
                       (3, 0xFF, 0x0F), (4, 0xFF, 0x07)):
        s.seq(i, v)
        s('XREG %02x %02x' % (i, want))
    # asynchronous reset (bit 0 = 0) clears Character Map Select (TR p.23)
    s.seq(0, 0x02)
    s('XREG 03 00')
    s.seq(3, 0x05)
    s('XREG 03 00')                        # held clear while bit 0 = 0
    s.seq(0, 0x01).seq(3, 0x05)
    s('XREG 03 05')


@test
def reset_drv(s):
    # Sheet 9: RESET clears Misc Output (U37) and Feature Control (U49).
    s.ow(0x3C2, 0xE7).ow(0x3DA, 0x03)
    s('XREG 60 e7', 'XREG 61 03')
    s.crtc(0x0C, 0x44, 0x3D4)
    s('RST 1', 'XREG 60 00', 'XREG 61 00')
    s.ow(0x3C2, 0x55)                      # held clear while RESET DRV high
    s('XREG 60 00', 'RST 0')
    s('XREG 1c 44')                        # CRTC registers kept (E2)
    s.ow(0x3C2, 0x55)
    s('XREG 60 55')


# ----------------------------------------------------------- memory path
def ram_setup(s, gcmisc=0x05, seq4=0x06, misc=0x03):
    # bit mask FFh: the power-on value 00h (E1) would protect every bit
    s.ow(0x3C2, misc).seq(4, seq4).seq(2, 0x0F).gc(6, gcmisc).gc(8, 0xFF)
    s.ow(0x3CC, 0).ow(0x3CA, 1)
    return s


@test
def write_mode0(s):
    # TR p.47-55, write mode 0. GC misc 05h: A0000 for 64 KB.
    ram_setup(s)
    s.mw(0xA0010, 0x5A)
    for p in range(4):
        s('XMEM %d 0010 5a' % p)
    # rotate 3 (right, E33): 5Ah = 01011010 -> 01001011 = 4Bh
    s.gc(3, 0x03).mw(0xA0011, 0x5A)
    s('XMEM 0 0011 4b', 'XMEM 3 0011 4b')
    # set/reset 0101b, enable 0011b: plane0 = FF, plane1 = 00, planes 2/3 =
    # rotated CPU data 4Bh
    s.gc(0, 0x05).gc(1, 0x03).mw(0xA0012, 0x5A)
    s('XMEM 0 0012 ff', 'XMEM 1 0012 00', 'XMEM 2 0012 4b', 'XMEM 3 0012 4b')
    s.gc(1, 0x00).gc(3, 0x00)
    # functions with latches: fill A0020 with planes 0F/F0/33/CC, read it
    planes_fill(s, 0x20, [0x0F, 0xF0, 0x33, 0xCC])
    s('MR a0020')                          # read mode 0, map 0 -> 0F
    s.gc(3, 0x08).mw(0xA0021, 0x3C)        # AND: 0F&3C=0C F0&3C=30 33&3C=30 CC&3C=0C
    s('XMEM 0 0021 0c', 'XMEM 1 0021 30', 'XMEM 2 0021 30', 'XMEM 3 0021 0c')
    s.gc(3, 0x10).mw(0xA0022, 0x3C)        # OR: 3F FC 3F FC
    s('XMEM 0 0022 3f', 'XMEM 1 0022 fc', 'XMEM 2 0022 3f', 'XMEM 3 0022 fc')
    s.gc(3, 0x18).mw(0xA0023, 0x3C)        # XOR: 33 CC 0F F0
    s('XMEM 0 0023 33', 'XMEM 1 0023 cc', 'XMEM 2 0023 0f', 'XMEM 3 0023 f0')
    # bit mask F0h with function none: high nibble from data (A5 -> A0),
    # low nibble from latch: 0A? plane0 latch 0F -> A0|0F = AF; plane1 F0 ->
    # A0|00 = A0; plane2 33 -> A3; plane3 CC -> AC
    s.gc(3, 0x00).gc(8, 0xF0).mw(0xA0024, 0xA5)
    s('XMEM 0 0024 af', 'XMEM 1 0024 a0', 'XMEM 2 0024 a3', 'XMEM 3 0024 ac')
    # set/reset with function XOR and mask: SR=1111 ESR=1111, mask 0F:
    # FF ^ latch, low nibble only: 0F->00 ... plane0 (FF^0F)&0F | 0F&F0 = 00
    s.gc(0, 0x0F).gc(1, 0x0F).gc(3, 0x18).gc(8, 0x0F).mw(0xA0025, 0x00)
    s('XMEM 0 0025 00', 'XMEM 1 0025 ff', 'XMEM 2 0025 3c', 'XMEM 3 0025 c3')


@test
def write_modes_1_2_3(s):
    ram_setup(s)
    planes_fill(s, 0x30, [0x11, 0x22, 0x44, 0x88])
    s('MR a0030')
    s.gc(5, 0x01).gc(8, 0x00).mw(0xA0031, 0x00)   # write mode 1: latches,
    s('XMEM 0 0031 11', 'XMEM 1 0031 22', 'XMEM 2 0031 44', 'XMEM 3 0031 88')
    # write mode 2 (TR p.51): plane n = 8 copies of data bit n. Data 05h ->
    # FF 00 FF 00; bit mask F0h keeps the latch low nibble: F1 02 F4 08
    s.gc(5, 0x02).gc(8, 0xF0).mw(0xA0032, 0x05)
    s('XMEM 0 0032 f1', 'XMEM 1 0032 02', 'XMEM 2 0032 f4', 'XMEM 3 0032 08')
    # write mode 2 with OR: (bit ? FF : 00) | latch, mask FF: data 0Ah ->
    # 11 FF 44 FF
    s.gc(3, 0x10).gc(8, 0xFF).mw(0xA0033, 0x0A)
    s('XMEM 0 0033 11', 'XMEM 1 0033 ff', 'XMEM 2 0033 44', 'XMEM 3 0033 ff')
    # write mode 3: not valid, nothing written (E29)
    s.gc(5, 0x03).gc(3, 0x00).mw(0xA0030, 0x77)
    s('XMEM 0 0030 11', 'XMEM 3 0030 88')
    # map mask 0101b: only planes 0 and 2 written (TR p.21)
    s.gc(5, 0x00).seq(2, 0x05).mw(0xA0034, 0x99)
    s('XMEM 0 0034 99', 'XMEM 1 0034 00', 'XMEM 2 0034 99', 'XMEM 3 0034 00')


@test
def read_modes(s):
    ram_setup(s)
    planes_fill(s, 0x40, [0x0F, 0x33, 0x55, 0xFF])
    for m, v in ((0, 0x0F), (1, 0x33), (2, 0x55), (3, 0xFF)):
        s.gc(4, m)
        s('MR a0040 %02x' % v)
    for m in (4, 5, 6, 7):                 # no controller selected: FF (E30)
        s.gc(4, m)
        s('MR a0040 ff')
    s('XREG 62 0f', 'XREG 63 33', 'XREG 64 55', 'XREG 65 ff')
    # read mode 1 (TR p.48/52): colour compare 1011b, all planes compared
    # (E15): bit = 1 where p0=1,p1=1,p2=0,p3=1. p0=0F p1=33 p2=55 p3=FF:
    # p0&p1&~p2&p3 = 0F&33&AA&FF = 02
    s.gc(5, 0x08).gc(2, 0x0B).gc(7, 0x0F)
    s('MR a0040 02')
    # don't care for planes 2 and 3 (bits 0): p0&p1 = 03
    s.gc(7, 0x03)
    s('MR a0040 03')
    # no plane compared: FF
    s.gc(7, 0x00)
    s('MR a0040 ff')


@test
def odd_even_and_chain(s):
    # Text-mode addressing: seq memory mode 03h (odd/even, TR p.23), GC
    # mode 10h (odd/even read), GC misc 0Eh (chain, B8000 32 KB), misc 23h
    # (page bit 1). E28: chained plane address = (offset & FFFE) | NOT page.
    ram_setup(s, gcmisc=0x0E, seq4=0x03, misc=0x23)
    s.gc(5, 0x10)
    s.mw(0xB8000, 0x41).mw(0xB8001, 0x1E).mw(0xB8002, 0x42).mw(0xB8003, 0x07)
    s('XMEM 0 0000 41', 'XMEM 1 0000 1e', 'XMEM 0 0002 42', 'XMEM 1 0002 07')
    s('XMEM 2 0000 41', 'XMEM 3 0000 1e')   # map mask 0Fh: 0/2 even, 1/3 odd
    s('MR b8000 41', 'MR b8001 1e', 'MR b8003 07')
    s.gc(4, 0x02)
    s('MR b8000 41', 'MR b8001 1e')         # rms bit 1 selects planes 2/3
    # page bit 0: plane address bit 0 = 1
    s.ow(0x3C2, 0x03).gc(4, 0)
    s.mw(0xB8004, 0x61)
    s('XMEM 0 0005 61', 'XMEM 0 0004 00')
    # 128 KB map with chain: A16 replaces A0 (E28): B0006 -> offset 10006h
    s.gc(6, 0x02)
    s.mw(0xB0006, 0x62).mw(0xA0006, 0x63)
    s('XMEM 0 0007 62', 'XMEM 0 0006 63')
    # not chained, 128 KB map: A16 ignored, B0008 aliases A0008
    s.gc(6, 0x00).seq(4, 0x06)
    s.mw(0xB0008, 0x64)
    s('MR a0008 64')


@test
def memory_maps(s):
    # GC misc bits 3-2 (TR p.53); misc bit 1 enables RAM (TR p.13).
    ram_setup(s, gcmisc=0x04)
    s.mw(0xA1234, 0x11)
    s('MR a1234 11', 'MR b1234 Z', 'XMEM 0 1234 11')
    s.gc(6, 0x08)                         # B0000, 32 KB
    s.mw(0xB1234, 0x22)
    s('MR b1234 22', 'MR a1234 Z', 'MR b8000 Z', 'XMEM 1 1234 22')
    s.gc(6, 0x0C)                         # B8000, 32 KB
    s.mw(0xB9234, 0x33)
    s('MR b9234 33', 'MR b1234 Z', 'XMEM 2 1234 33')
    s.gc(6, 0x00)                         # A0000, 128 KB, not chained:
    # B9234 -> offset 19234h, A16 ignored -> plane address 9234h (empty);
    # B1234 -> 11234h -> 1234h, written last with 33h
    s('MR b9234 00', 'MR b1234 33', 'MR a1234 33')
    s.ow(0x3C2, 0x01)                     # RAM disabled
    s('MR a1234 Z')
    s.mw(0xA1234, 0x44)
    s.ow(0x3C2, 0x03)
    s('MR a1234 33')
    s('DACK 0', 'MR a1234 Z', 'MR c0000 Z', 'DACK 1')  # U48 G1


@test
def extended_memory_bit(s):
    # Memory Mode bit 1 (TR p.23): address bits 14-15 only with it set.
    ram_setup(s, gcmisc=0x04, seq4=0x04)
    s.mw(0xA4001, 0x5E)
    s('XMEM 0 0001 5e', 'XMEM 0 4001 00')
    s.seq(4, 0x06).mw(0xA4001, 0x6E)
    s('XMEM 0 4001 6e', 'XMEM 0 0001 5e')


@test
def gc_position(s):
    # Swapped positions: GC 1 (planes 0/1) uses bits 2/3, GC 2 bits 0/1.
    ram_setup(s)
    s.ow(0x3CC, 1).ow(0x3CA, 0)
    s.gc(0, 0x06).gc(1, 0x0F).mw(0xA0050, 0x00)
    # plane0 <- SR bit2 = 1, plane1 <- bit3 = 0, plane2 <- bit0 = 0, plane3 <- bit1 = 1
    s('XMEM 0 0050 ff', 'XMEM 1 0050 00', 'XMEM 2 0050 00', 'XMEM 3 0050 ff')
    s.gc(1, 0x00).gc(4, 0x00)
    s('MR a0050 00')                      # map 0 -> GC 2 (position 0), plane 2
    s.ow(0x3CC, 0).ow(0x3CA, 0)           # both at position 0: AND (E30)
    s('MR a0050 00')
    s.gc(4, 0x01)
    s('MR a0050 00')                      # plane1 (00) AND plane3 (FF)


@test
def rom_read(s):
    # ROM at C0000-C3FFF (TR p.4), header 55 AA 20 EB 28 (listing 605-606)
    s('MR c0000 55', 'MR c0001 aa', 'MR c0002 20', 'MR c0003 eb', 'MR c0004 28',
      'MR c0005 32', 'MR c3fff 46', 'MR c4000 Z', 'MR bffff Z')
    s.mw(0xC0000, 0x00)
    s('MR c0000 55')


# ------------------------------------------------------------------ video
@test
def tiny_frame_timing(s):
    # One frame of the tiny geometry, graphics, all planes zero: border
    # (overscan 2Ah) and blanking only.
    tiny(s)
    run_seq(s)
    s('T 392', 'XDOTS 392')               # 7 lines x 56 dots
    # line 0, output char 0-1: display enable comes from counter chars -2/-1
    # of the previous line (stale pipeline: zeros), so border would show;
    # at power-on the pipeline holds zeros -> de 0, blank 0 -> overscan 2Ah,
    # retrace low, video drivers on (bit 10).
    s('XPIX %d 7ff 42a' % dot(0, 0))
    # output char 2 = counter char 0 of line 0: displayed, palette[0] = 00
    s('XPIX %d 7ff 600' % dot(0, 2))      # de bit 9, oe bit 10
    s('XPIX %d 7ff 600' % dot(0, 4, 7))
    # output char 5: blank (counter char 4, lag 1) + retrace (char 5, lag 0)
    s('XPIX %d 7ff 540' % dot(0, 5))
    # output char 6: blank (counter char 5), no retrace, no display
    s('XPIX %d 7ff 500' % dot(0, 6))
    # line 3 is vertically blanked (vc 3 from line 2 char 6, lag 1 -> line
    # 3 char 0); line 4 carries vertical retrace (vc 4 from line 3 char 6,
    # lag 0 -> line 3 char 6 .. line 4 char 5)
    s('XPIX %d 7ff 500' % dot(3, 0))
    s('XPIX %d 7ff 580' % dot(3, 6))
    s('XPIX %d 7ff 5c0' % dot(4, 5))
    s('XPIX %d 7ff 500' % dot(4, 6))
    # line 5: vertical blank ends when vc low 5 bits = 5 (from line 4 char
    # 6, blank lag 1 -> line 5 char 0 unblanked): border at char 0
    s('XPIX %d 7ff 42a' % dot(5, 0))


@test
def graphics_pixels(s):
    # Planar graphics (TR p.10): plane n = colour bit n; bit 7 = first pel.
    tiny(s)
    planes_fill(s, 0x00, [0x80, 0x40, 0x20, 0x10])   # pel0=1 pel1=2 pel2=4 pel3=8
    planes_fill(s, 0x05, [0xFF, 0x00, 0x00, 0xFF])   # row 1 (Offset 2 -> +4), char 1
    s.attr(0x01, 0x3F).attr(0x09, 0x15)
    s('OR 3da').ow(0x3C0, 0x20)
    run_seq(s)
    s('T 392')
    s('XPIX %d 3f 3f' % dot(0, 2, 0))     # palette[1] = 3F
    s('XPIX %d 3f 02' % dot(0, 2, 1))
    s('XPIX %d 3f 04' % dot(0, 2, 2))
    s('XPIX %d 3f 08' % dot(0, 2, 3))
    s('XPIX %d 3f 00' % dot(0, 2, 4))
    s('XPIX %d 3f 15' % dot(1, 3, 0))     # line 1, counter char 1 -> 9h
    s('XPIX %d 3f 15' % dot(1, 3, 7))
    # colour plane enable 1110b masks bit 0 (TR p.60): pel0 index 1 -> 0
    s.attr(0x12, 0x0E)
    s('OR 3da').ow(0x3C0, 0x20)
    s('T 392')
    s('XPIX %d 3f 00' % dot(0, 2, 0))
    s('XPIX %d 3f 02' % dot(0, 2, 1))
    s('XPIX %d 3f 08' % dot(1, 3, 0))     # 9h & Eh = 8h -> palette 08


@test
def shift_register_mode(s):
    # GC mode bit 5 (TR p.52) with CGA 320x200 format (TR p.8): plane 0
    # byte 0 holds pels 0-3, two bits each (C1 = high bit), plane 1 pels 4-7.
    tiny(s, gcmode=0x20)
    planes_fill(s, 0x00, [0b11100100, 0b00011011, 0, 0])
    s('OR 3da').ow(0x3C0, 0x20)
    run_seq(s)
    s('T 392')
    for j, v in enumerate([3, 2, 1, 0, 0, 1, 2, 3]):
        s('XPIX %d 0f %02x' % (dot(0, 2, j), v))


@test
def shift_load(s):
    # Clocking Mode bit 2 (TR p.20) + ASSUMPTION E19: even counter
    # characters show the even plane, odd ones the odd plane, on C0/C2.
    tiny(s, seq1=0x05)
    planes_fill(s, 0x00, [0x80, 0x01, 0x00, 0x00])
    planes_fill(s, 0x01, [0x00, 0x40, 0x00, 0x00])
    run_seq(s)
    s('T 392')
    s('XPIX %d 0f 01' % dot(0, 2, 0))     # counter char 0: plane 0 bit 7
    s('XPIX %d 0f 00' % dot(0, 2, 7))
    s('XPIX %d 0f 01' % dot(0, 3, 1))     # counter char 1 (odd): plane 1 bit 6 -> C0


@test
def text_glyphs(s):
    # Alphanumeric (TR p.8, p.58): char code in plane 0, attribute in
    # plane 1, font in plane 2 at char*32 + row (TR p.69-70).
    tiny(s, attr_mode=0x00, gcmisc=0x04, seq4=0x07)
    planes_fill(s, 0x00, [0x41, 0x1E, 0x00, 0x00])   # 'A', yellow on blue
    s.seq(2, 0x04).mw(0xA0000 + 0x41 * 32, 0b10110001).seq(2, 0x0F)
    for i in range(16):
        s.attr(i, i)
    s('OR 3da').ow(0x3C0, 0x20)
    run_seq(s)
    s('T 392')
    for j, b in enumerate([1, 0, 1, 1, 0, 0, 0, 1]):
        s('XPIX %d 3f %02x' % (dot(0, 2, j), 0x0E if b else 0x01))
    # char 1 at plane address 1: code 00, attribute 00 -> font of char 0
    # (zero) -> background palette[0]
    s('XPIX %d 3f 00' % dot(0, 3, 0))


@test
def text_nine_dot_and_line_graphics(s):
    # 9-dot characters (Clocking bit 0 = 0, TR p.20) and the line-graphics
    # bit (TR p.58): codes C0-DF repeat dot 8 in dot 9, others show
    # background. Line = 7 x 9 = 63 dots.
    tiny(s, attr_mode=0x04, gcmisc=0x04, seq4=0x07, seq1=0x00)
    planes_fill(s, 0x00, [0xC4, 0x07, 0, 0])
    planes_fill(s, 0x01, [0x41, 0x07, 0, 0])
    s.seq(2, 0x04).mw(0xA0000 + 0xC4 * 32, 0xFF).mw(0xA0000 + 0x41 * 32, 0xFF)
    s.seq(2, 0x0F)
    # 9-dot panning sequence 8,0,..,7 (TR p.61): 8 = no shift, as the BIOS
    # programs for mode 7
    s.attr(0x13, 0x08)
    s('OR 3da').ow(0x3C0, 0x20)
    run_seq(s)
    s('T 441', 'XDOTS 441')
    s('XPIX %d 3f 07' % (2 * 9 + 7))      # char C4h dot 8
    s('XPIX %d 3f 07' % (2 * 9 + 8))      # dot 9 = dot 8 (line graphics)
    s('XPIX %d 3f 07' % (3 * 9 + 7))      # char 41h dot 8
    s('XPIX %d 3f 00' % (3 * 9 + 8))      # dot 9 = background 0
    s.attr(0x10, 0x00)
    s('OR 3da').ow(0x3C0, 0x20)
    s('T 441')
    # second frame starts at dot 441 of the run? no: the run continues
    # from the end of the frame, i.e. at line 0 char 0 again.
    s('XPIX %d 3f 00' % (2 * 9 + 8))      # line graphics off: background


@test
def text_attributes_blink(s):
    # TR p.59: blink bit 3 = 0 -> attribute bit 7 = background intensity;
    # 1 -> blink. ASSUMPTION E23: blink phase = blink counter bit 4.
    tiny(s, attr_mode=0x00, gcmisc=0x04, seq4=0x07)
    planes_fill(s, 0x00, [0x01, 0x9C, 0, 0])   # char 1, attr: bg 9 (blink bit), fg C
    s.seq(2, 0x04).mw(0xA0000 + 0x20, 0xF0).seq(2, 0x0F)
    s('OR 3da').ow(0x3C0, 0x20)
    run_seq(s)
    s('T 392')
    s('XPIX %d 3f 0c' % dot(0, 2, 0))     # fg C
    s('XPIX %d 3f 09' % dot(0, 2, 4))     # bg = attr bits 7-4 = 9
    s.attr(0x10, 0x08)
    s('OR 3da').ow(0x3C0, 0x20)
    s('T 392')
    s('XPIX %d 3f 0c' % dot(0, 2, 0))     # counter 1 (bit 4 = 0): visible
    s('XPIX %d 3f 01' % dot(0, 2, 4))     # bg = bits 6-4 = 1
    s('T %d' % (392 * 14))                # 16 frames: counter reaches 16
    s('XREG 68 10')
    s('T 392')
    s('XPIX %d 3f 01' % dot(0, 2, 0))     # blink-off: foreground hidden


@test
def cursor_shapes(s):
    # Cursor at location 1, rows CS <= rs < CE (E16), tiny geometry with 4
    # scan lines per row (MSL 3) and 7 lines: row 0 = lines 0-3.
    c = list(TINY_CRTC)
    c[9] = 0x03
    c[0x0A], c[0x0B], c[0x0E], c[0x0F] = 0x01, 0x03, 0x00, 0x01
    tiny(s, crtc=c, attr_mode=0x00, gcmisc=0x04, seq4=0x07)
    planes_fill(s, 0x01, [0x00, 0x0A, 0, 0])   # char 1: code 0, fg A, bg 0
    planes_fill(s, 0x02, [0x00, 0x0C, 0, 0])   # char 2: fg C (E23: cursor
    #                                            takes the char's foreground)
    s('OR 3da').ow(0x3C0, 0x20)
    run_seq(s)
    s('T 392')
    s('XPIX %d 3f 00' % dot(0, 3, 0))     # rs 0: no cursor
    s('XPIX %d 3f 0a' % dot(1, 3, 0))     # rs 1: cursor = foreground
    s('XPIX %d 3f 0a' % dot(2, 3, 5))     # rs 2
    s('XPIX %d 3f 00' % dot(2, 2, 0))     # char 0 never
    # rs 3 is line 3 (vertically blanked in tiny); end exclusive anyway.
    # cursor skew 1 (Cursor End bits 6-5): one character later
    s.crtc(0x0B, 0x23)
    s('T 392')
    s('XPIX %d 3f 00' % dot(1, 3, 0))
    s('XPIX %d 3f 0c' % dot(1, 4, 0))
    # start >= end: no cursor
    s.crtc(0x0B, 0x01)
    s('T 392')
    s('XPIX %d 3f 00' % dot(1, 3, 0))


@test
def underline(s):
    # Monochrome attributes (Mode bit 1) underline 01h on row UL (E22).
    c = list(TINY_CRTC)
    c[9] = 0x03
    c[0x14] = 0x02
    tiny(s, crtc=c, attr_mode=0x02, gcmisc=0x04, seq4=0x07)
    planes_fill(s, 0x00, [0x00, 0x01, 0, 0])
    planes_fill(s, 0x01, [0x00, 0x02, 0, 0])
    s('OR 3da').ow(0x3C0, 0x20)
    run_seq(s)
    s('T 392')
    s('XPIX %d 3f 00' % dot(1, 2, 0))     # row 1: background
    s('XPIX %d 3f 01' % dot(2, 2, 0))     # row 2: underline in fg 1
    s('XPIX %d 3f 00' % dot(2, 3, 0))     # attribute 02h: not underlined
    s.attr(0x10, 0x00)
    s('OR 3da').ow(0x3C0, 0x20)
    s('T 392')
    s('XPIX %d 3f 00' % dot(2, 2, 0))     # colour attributes: no underline


@test
def panning(s):
    # Horizontal pel panning (TR p.61): 8-dot shift 0-7 from the next char.
    tiny(s)
    planes_fill(s, 0x00, [0x01, 0, 0, 0])
    planes_fill(s, 0x01, [0x80, 0, 0, 0])
    run_seq(s)
    for p in (0, 1, 3, 7):
        s.attr(0x13, p)
        s('OR 3da').ow(0x3C0, 0x20)
        s('T 392')
        # pel 7 of char 0 shows at dot 7-p, pel 0 of char 1 at dot 8-p
        s('XPIX %d 0f 01' % dot(0, 2, 7 - p))
        s('XPIX %d 0f 01' % dot(0, 2, 8 - p))
    s.attr(0x13, 0x08)
    s('OR 3da').ow(0x3C0, 0x20)
    s('T 392')
    s('XPIX %d 0f 01' % dot(0, 2, 7))     # 8 -> bits 2-0 = 0 (E24)


@test
def panning_nine_dot(s):
    # 9-dot: the panning sequence 8,0,1,...,7 shifts 0..8 pels (TR p.61).
    # Char 0 = code 01h, attribute 0Fh, font row 0 = 01h (only pel 7 on).
    # Pel 7 of counter char 0 normally shows at output dot 2*9+7 = 25 and
    # moves left by the shift; the border (display enable off, output char
    # 1) is not shifted.
    tiny(s, seq1=0x00, attr_mode=0x00, gcmisc=0x04, seq4=0x07)
    planes_fill(s, 0x00, [0x01, 0x0F, 0, 0])
    s.seq(2, 0x04).mw(0xA0020, 0x01).seq(2, 0x0F)
    run_seq(s)
    for p, sh in ((8, 0), (0, 1), (1, 2), (6, 7)):
        s.attr(0x13, p)
        s('OR 3da').ow(0x3C0, 0x20)
        s('T 441')
        s('XPIX %d 3f 0f' % (25 - sh))
        s('XPIX %d 3f 00' % (26 - sh))
    s.attr(0x13, 0x07)                    # shift 8: pel 7 lands in the border
    s('OR 3da').ow(0x3C0, 0x20)
    s('T 441')
    s('XPIX 17 3f 2a', 'XPIX 18 3f 00')


@test
def palette_source(s):
    # E27: attribute address bit 5 = 0 -> overscan instead of the palette.
    tiny(s)
    planes_fill(s, 0x00, [0xFF, 0, 0, 0])
    s.attr(1, 0x3F)
    run_seq(s)
    s('T 392')
    s('XPIX %d 3f 2a' % dot(0, 2, 0))     # PAS = 0 after attr() -> overscan
    s('OR 3da').ow(0x3C0, 0x20)
    s('T 392')
    s('XPIX %d 3f 3f' % dot(0, 2, 0))


@test
def graphics_blink(s):
    # E20 with the mode F palette idea: index bit 3 forced in blink-off.
    tiny(s, attr_mode=0x09)
    planes_fill(s, 0x00, [0x00, 0x00, 0xFF, 0x00])   # index 4
    s.attr(0x04, 0x18).attr(0x0C, 0x00)
    s('OR 3da').ow(0x3C0, 0x20)
    run_seq(s)
    s('T 392')
    s('XPIX %d 3f 18' % dot(0, 2, 0))
    s('T %d' % (392 * 15))
    s('XREG 68 10', 'T 392')
    s('XPIX %d 3f 00' % dot(0, 2, 0))


@test
def split_screen(s):
    # Line compare (TR p.43, p.74): after line LC the address restarts at 0.
    c = list(TINY_CRTC)
    c[0x0C], c[0x0D] = 0x00, 0x40          # start address 40h
    c[0x18] = 0x00                         # LC = 0 (bit 8 cleared below)
    tiny(s, crtc=c)
    s.crtc(0x07, 0x00)
    planes_fill(s, 0x40, [0x80, 0, 0, 0])  # screen A, line 0
    planes_fill(s, 0x00, [0x40, 0, 0, 0])  # screen B row 0 (line 1)
    planes_fill(s, 0x04, [0x20, 0, 0, 0])  # screen B row 1 (line 2)
    # frame 0 starts with row start 0 (power-on); run two frames
    run_seq(s)
    s('T 784')
    base = 392
    s('XPIX %d 0f 01' % (base + dot(0, 2, 0)))
    s('XPIX %d 0f 01' % (base + dot(1, 2, 1)))
    s('XPIX %d 0f 01' % (base + dot(2, 2, 2)))


@test
def preset_row_scan_and_word_mode(s):
    # Preset row scan (TR p.32) and word-mode address output (TR p.43).
    c = list(TINY_CRTC)
    c[0x08] = 0x02
    c[0x09] = 0x03
    c[0x17] = 0xA3                         # word mode, MA13 wrap, CMS0/SRS off
    tiny(s, crtc=c)
    # word mode: counter MA = c, address = c << 1 -> char 1 at address 2
    planes_fill(s, 0x02, [0x80, 0, 0, 0])
    run_seq(s)
    s('T 784')
    # frame 1: line 0 has rs = 2 (preset); MSL 3 -> lines 0,1 = row 0
    s('XPIX %d 0f 01' % (392 + dot(0, 3, 0)))
    s('XPIX %d 0f 01' % (392 + dot(1, 3, 0)))
    s('XPIX %d 0f 00' % (392 + dot(2, 3, 0)))   # line 2: row 1 (address 4+2)


@test
def cms0_and_srs(s):
    # Mode Control bits 0/1 (TR p.41-42): rs0 -> address bit 13, rs1 -> 14.
    c = list(TINY_CRTC)
    c[0x09] = 0x03
    c[0x13] = 0x00
    c[0x17] = 0xE0                         # byte mode, CMS0 = 0, SRS = 0
    tiny(s, crtc=c)
    planes_fill(s, 0x2000, [0x80, 0, 0, 0])
    planes_fill(s, 0x4000, [0x40, 0, 0, 0])
    planes_fill(s, 0x6000, [0x20, 0, 0, 0])
    run_seq(s)
    s('T 392')
    s('XPIX %d 0f 01' % dot(1, 2, 0))
    s('XPIX %d 0f 01' % dot(2, 2, 1))
    s('XPIX %d 0f 00' % dot(0, 2, 0))


@test
def count_by_two(s):
    # Mode Control bit 3: MA advances every second character.
    c = list(TINY_CRTC)
    c[0x17] = 0xEB
    tiny(s, crtc=c)
    planes_fill(s, 0x00, [0x80, 0, 0, 0])
    planes_fill(s, 0x01, [0x40, 0, 0, 0])
    run_seq(s)
    s('T 392')
    s('XPIX %d 0f 01' % dot(0, 2, 0))
    s('XPIX %d 0f 01' % dot(0, 3, 0))     # same address for chars 0 and 1
    s('XPIX %d 0f 01' % dot(0, 4, 1))     # char 2 -> address 1


@test
def dot_clock_div2_and_sequencer_reset(s):
    # Clocking Mode bit 3 (TR p.20): dot = master / 2 (E7: first pulse).
    tiny(s, seq1=0x09)
    run_seq(s)
    s('T 100', 'XDOTS 50')
    s('T 101', 'XDOTS 51')
    s.seq(0, 0x01)
    s('T 20', 'XDOTS 0')                  # halted (E6)
    s.seq(0, 0x03)
    s('T 2', 'XDOTS 1')
    s.ow(0x3C2, 0x0B)                     # clock select 10: EXT (tied off)
    s('T 10', 'XDOTS 0')
    s.ow(0x3C2, 0x0F)                     # 11: no clock
    s('T 10', 'XDOTS 0')
    s.ow(0x3C2, 0x07)                     # 01: 16 MHz
    s('T 10', 'XDOTS 5')


@test
def vertical_interrupt(s):
    # TR p.37, p.72-73: VRE bit 5 = 0 enables, bit 4 = 0 clears; latch set
    # at the start of vertical retrace (line 4 of tiny, from line 3 char 5).
    c = list(TINY_CRTC)
    c[0x11] = 0x15                         # enable (bit5=0), not clearing
    tiny(s, crtc=c)
    run_seq(s)
    s('T %d' % (dot(3, 5) + 8))           # through line 3 char 5
    s('XIRQ 1', 'OR 3c2 9f')          # switches open: bit 4 = 1
    s.crtc(0x11, 0x05)                    # clear
    s('XIRQ 0', 'OR 3c2 1f')
    s.crtc(0x11, 0x15)
    s('T 392', 'XIRQ 1')
    s.crtc(0x11, 0x05).crtc(0x11, 0x35)   # disabled: no new latch
    s('T 392', 'XIRQ 0')


@test
def status_bits(s):
    # ISR1 (TR p.16) with E10/E11.
    tiny(s)
    planes_fill(s, 0x00, [0xFF, 0, 0, 0])
    s.attr(1, 0x2D)                        # 101101: R' g' B' ... bits 5,3,2,0
    s('OR 3da').ow(0x3C0, 0x20)
    run_seq(s)
    s('T %d' % (dot(0, 2) + 1))           # first dot of output char 2
    # displayed, last colour 2Dh: mux 00 -> bit5 = R (bit 2) = 1, bit4 = B
    # (bit 0) = 1; vertical retrace 0; display on -> bit 0 = 0; LP switch
    # open -> bit 2 = 1.
    s('OR 3da f4')
    s.attr(0x12, 0x1F)                     # mux 01: B' (bit 3)=1, G (bit 1)=0
    s('OR 3da e4')
    s.attr(0x12, 0x2F)                     # mux 10: R' (bit 5)=1, G' (bit 4)=0
    s('OR 3da e4')
    s.attr(0x12, 0x3F)
    s('OR 3da c4')
    s('T 32')                             # into blank/retrace at char 5
    s('OR 3da c5')


@test
def light_pen(s):
    # Light-pen flip-flop (sheet 9 U18) and CRTC latch (TR p.36-38).
    tiny(s)
    run_seq(s)
    s('T 16')                             # chars 0,1 of line 0 (ma 0,1)
    s('LP 0', 'LP 1')                     # falling edge sets the flip-flop
    s('XREG 66 01')
    s('T 8')                              # boundary of char 2: latch ma = 2
    s('OR 3da c6')                        # bit 1 strobe, bit 2 switch open, bit 0 = 0
    #                                       (output char 2 is displayed)
    s.crtc(0x10, 0)
    s('OR 3d5 00')
    s.crtc(0x11, 0)
    s('OR 3d5 02')
    s.ow(0x3DB, 0)                        # LP CLR (E5)
    s('XREG 66 00')
    s('LPSW 0', 'OR 3da c0')              # switch closed -> bit 2 = 0, strobe cleared
    s.ow(0x3DC, 0)                        # LP SET
    s('XREG 66 01')


@test
def reset_drv_holds_crtc(s):
    # E2: RESET DRV holds the CRTC counters; misc cleared (sheet 9).
    tiny(s)
    run_seq(s)
    s('T 96')                             # 12 whole characters
    s('RST 1', 'RST 0')
    s.ow(0x3C2, 0x03)
    s('T 392')
    # counters restarted at line 0 char 0; the first two output chars carry
    # stale pipeline data, char 2 onward is the fresh frame:
    s('XPIX %d 7ff 600' % dot(0, 2))
    s('XPIX %d 7ff 540' % dot(0, 5))


@test
def sync_polarity_and_drivers(s):
    # Misc bits 6/7 invert the retraces (U8), bit 4 disables U36, P1.
    tiny(s, misc=0xC3)
    planes_fill(s, 0x00, [0xFF, 0, 0, 0])
    s.attr(1, 0x3F)
    s('OR 3da').ow(0x3C0, 0x20)
    run_seq(s)
    s('T 392')
    s('XPIX %d 7ff 6ff' % dot(0, 2))      # colour 3F, both syncs inverted high
    s('XPIX %d 0c0 80' % dot(0, 5))       # hsync active -> low
    s.ow(0x3C2, 0x13)
    s('P1 0', 'T 392')
    s('XPIX %d 7ff 21f' % dot(0, 2))      # oe 0, R' forced 0 (pin 2 ground)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    names = []
    for fn in TESTS:
        s = S()
        fn(s)
        with open(os.path.join(out, fn.__name__ + '.txt'), 'w') as f:
            f.write('# directed test: %s\n' % fn.__name__ + s.text())
        names.append(fn.__name__)
    with open(os.path.join(out, 'list.txt'), 'w') as f:
        f.write('\n'.join(names) + '\n')
    print('wrote %d directed tests' % len(names))


if __name__ == '__main__':
    main()
