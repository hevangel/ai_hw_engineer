#!/usr/bin/env python3
"""Replay of the IBM EGA BIOS power-on, mode-set and font-load sequences.

usage: bios_replay.py gen   ROM_CPU_ORDER OUTDIR
       bios_replay.py check ROM_CPU_ORDER OUTDIR/<name>

gen writes replay_mode3.txt (mode 3, IBM Color Display, switches 0111b),
replay_mode3_enh.txt (mode 3 on the Enhanced Color Display, switches
1001b: 8x14 font and entry 16h) and replay_mode7.txt (mode 7, IBM
Monochrome Display, switches 1011b). Each replays, through the slot pins,
the port and memory accesses of the BIOS code (ROM 6277356, listing and
disassembly addresses given below), in order:

1. VIDEO_SETUP entry (C000:002D-0039, listing 619-626): IN 3DA, IN 3BA,
   OUT 3C0,00.
2. Switch sense (C000:009B-00CD): OUT 3C2,01, then OUT 3C2,0D/09/05/01 each
   followed by IN 3C2; bit 4 of each read goes to INFO_3 bits 0-3.
3. Feature-bit read (C000:00CE-00F2): OUT 3BA/3DA,1; IN 3C2; OUT 3BA/3DA,2;
   IN 3C2.
4. Mode set (AH=0, C000:0F35 ff.): the character-generator load CH_GEN
   (C000:1EAE): SET_REGS with the font-load entry 0Bh (or 0Ch for mode 7),
   then DO_MAP2 (C000:1EF6): for each of 256 characters, REP MOVSB of the
   font rows from the ROM (read through the card at C0000h+offset) to
   A000:char*32; for mode 7 the 9-dot patch table CGMN_FDG at 3030h
   (C000:0FC0-0FDA); then SET_REGS for the mode (C000:0DAB), BLANK
   (C000:0E55: REP STOSW 0720h over 4000h words of the regen buffer) and
   PAL_ON (C000:1DB7: IN status, OUT 3C0,20h).
5. A test screen written as the BIOS write routines store text (character
   at even, attribute at odd addresses) and the cursor location set in
   CRTC 0Eh/0Fh, then three frames of dots.

The power-on self test's memory and display tests between steps 3 and 4
are not replayed.

check rebuilds the expected screen independently of the model: glyphs from
the ROM's own font table (plus the mode 7 patches), the documented text
attribute format (TR p.8, p.58-59), the palette and cursor registers from
the ROM's VIDEO_PARMS entry, ASSUMPTION E16 (cursor rows) and E22 (mono
underline), and compares it pixel for pixel with the displayed area of the
last complete frame in the RTL trace. It also checks that the switch
reads assemble INFO_3 as listing line 584-596 expects for each setting.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ega_bios as B  # noqa: E402

FDG = 0x3030          # CGMN_FDG: 9x14 patches (C000:0FC0 MOV BP,3030h)

REPLAYS = {
    # name: (mode, switches sw_i, INFO_3 expected, enhanced, description)
    'replay_mode3': (3, 0x7, 0x7, False, 'mode 3, Color Display, INFO_3 0111b'),
    'replay_mode3_enh': (3, 0x9, 0x9, True, 'mode 3, Enhanced Color Display, INFO_3 1001b'),
    'replay_mode7': (7, 0xB, 0xB, False, 'mode 7, Monochrome Display, INFO_3 1011b'),
}

TEXT = [
    (0, 0, 'IBM Enhanced Graphics Adapter - BIOS replay', 0x07),
    (1, 0, 'Bright white on blue', 0x1F),
    (2, 4, 'Yellow on red', 0x4E),
    (3, 0, 'Underline attribute 01h', 0x01),
    (4, 0, ''.join(chr(c) for c in range(0xB0, 0xE0)), 0x0F),
    (5, 2, 'Reverse 70h', 0x70),
    (6, 0, 'Blink bit 8Ah (visible phase)', 0x8A),
    (24, 60, 'last row', 0x0E),
]
CURSOR = (7, 5)


def screen(mode):
    cols = 80
    cells = {}
    for r, c, s, a in TEXT:
        for i, ch in enumerate(s):
            if c + i < cols:
                cells[(r, c + i)] = (ord(ch) & 0xFF, a)
    return cells


def font_table(rom, mode, enhanced):
    pts = 14 if (mode == 7 or enhanced) else 8
    base = B.FONT_8X14 if pts == 14 else B.FONT_8X8
    glyph = {ch: list(rom[base + ch * pts: base + ch * pts + pts]) for ch in range(256)}
    patches = []
    if mode == 7:
        bp = FDG
        while True:
            dx = rom[bp] | (rom[bp + 1] << 8)
            if dx == 0:
                break
            patches.append((dx, bp + 1))
            glyph[dx & 0xFF] = list(rom[bp + 1: bp + 15])
            bp += 15
    return pts, base, glyph, patches


def gen(rom, out):
    os.makedirs(out, exist_ok=True)
    for name, (mode, sw, info, enh, desc) in REPLAYS.items():
        mono = mode == 7
        s = ['# BIOS replay: ' + desc, 'SW %x' % sw, 'FEAT 3']
        # 1. VIDEO_SETUP entry
        s += ['OR 3da', 'OR 3ba', 'OW 3c0 00']
        # 2. switch sense
        s += ['OW 3c2 01']
        for v in (0x0D, 0x09, 0x05, 0x01):
            s += ['OW 3c2 %02x' % v, 'OR 3c2']
        # 3. feature bits
        s += ['OW 3ba 01', 'OW 3da 01', 'OR 3c2', 'OW 3ba 02', 'OW 3da 02', 'OR 3c2']
        # 4. mode set: CH_GEN font load
        pts, base, glyph, patches = font_table(rom, mode, enh)
        s += B.set_regs(B.entry(rom, 0x0C if mono else 0x0B), mono)
        for ch in range(256):
            for r in range(pts):
                off = base + ch * pts + r
                s += ['MR %05x %02x' % (0xC0000 + off, rom[off]),
                      'MW %05x %02x' % (0xA0000 + ch * 32 + r, rom[off])]
        for dx, src in patches:
            for r in range(14):
                s += ['MR %05x %02x' % (0xC0000 + src + r, rom[src + r]),
                      'MW %05x %02x' % (0xA0000 + ((dx << 5) & 0xFFFF) + r, rom[src + r])]
        ent = B.entry(rom, B.entry_index(mode, True, enh))
        s += B.set_regs(ent, mono)
        regen = 0xB0000 if mono else 0xB8000
        for i in range(0x4000):
            s += ['MW %05x 20' % (regen + 2 * i), 'MW %05x 07' % (regen + 2 * i + 1)]
        s += B.pal_on(mono)
        # 5. test screen and cursor
        for (r, c), (ch, a) in sorted(screen(mode).items()):
            o = 2 * (r * 80 + c)
            s += ['MW %05x %02x' % (regen + o, ch), 'MW %05x %02x' % (regen + o + 1, a)]
        crt = 0x3B4 if mono else 0x3D4
        loc = CURSOR[0] * 80 + CURSOR[1]
        s += ['OW %03x 0e' % crt, 'OW %03x %02x' % (crt + 1, loc >> 8),
              'OW %03x 0f' % crt, 'OW %03x %02x' % (crt + 1, loc & 0xFF)]
        c = ent['crtc']
        ht = c[0] + 2
        vt = (c[6] | ((c[7] & 1) << 8)) + 2
        w = 8 if ent['seq'][0] & 1 else 9
        s.append('T %d' % (3 * ht * w * vt + 100))
        with open(os.path.join(out, name + '.txt'), 'w') as f:
            f.write('\n'.join(s) + '\n')
    print('wrote %d BIOS replay scripts' % len(REPLAYS))


def expected(rom, mode, enh):
    ent = B.entry(rom, B.entry_index(mode, True, enh))
    pts, _, glyph, _ = font_table(rom, mode, enh)
    pal = ent['attr'][:16]
    amode = ent['attr'][0x10]
    w = 8 if ent['seq'][0] & 1 else 9
    c = ent['crtc']
    cs, ce, ul = c[0x0A] & 31, c[0x0B] & 31, c[0x14] & 31
    cells = screen(mode)
    img = []
    for row in range(25):
        for sl in range(pts):
            line = []
            for col in range(80):
                ch, at = cells.get((row, col), (0x20, 0x07))
                bits = glyph[ch][sl]
                fg = at & 15
                bg = (at >> 4) & 7 if amode & 8 else at >> 4      # TR p.59
                for j in range(w):
                    if j < 8:
                        g = (bits >> (7 - j)) & 1
                    else:                                         # TR p.58
                        g = bits & 1 if (amode & 4 and 0xC0 <= ch <= 0xDF) else 0
                    if amode & 2 and sl == ul and (at & 0x77) == 0x01:
                        g = 1                                     # E22
                    if (row, col) == CURSOR and cs <= sl < ce:
                        g = 1                                     # E16, E23
                    line.append(pal[fg if g else bg])
            img.append(line)
    return img


def check(rom, base):
    name = os.path.basename(base)
    mode, sw, info, enh, desc = REPLAYS[name]
    tr = base + '.rtl'
    # switch reads: 4 reads after OUT 3C2,0D/09/05/01 build INFO_3 bits 0-3
    reads = [ln.split() for ln in open(tr) if ln.startswith('R 03c2')]
    bits = [(int(r[2], 16) >> 4) & 1 for r in reads[:4]]
    got = bits[0] | (bits[1] << 1) | (bits[2] << 2) | (bits[3] << 3)
    if got != info:
        print('FAIL: %s: switch reads give INFO_3 %x, expected %x' % (name, got, info))
        sys.exit(1)
    feat = [(int(r[2], 16) >> 5) & 3 for r in reads[4:6]]
    ent = B.entry(rom, B.entry_index(mode, True, enh))
    hp, vp = (ent['misc'] >> 6) & 1, (ent['misc'] >> 7) & 1
    fr = B.frames(tr, hp, vp)
    f = fr[-2]
    vis = [[v & 0x3F for v in ln if (v >> 9) & 1] for ln in f]
    vis = [x for x in vis if x]
    exp = expected(rom, mode, enh)
    if len(vis) != len(exp) or any(len(a) != len(b) for a, b in zip(vis, exp)):
        print('FAIL: %s: displayed area %d lines x %s, expected %d x %d'
              % (name, len(vis), sorted(set(len(a) for a in vis)), len(exp), len(exp[0])))
        sys.exit(1)
    bad = [(y, x) for y in range(len(exp)) for x in range(len(exp[0])) if vis[y][x] != exp[y][x]]
    if bad:
        y, x = bad[0]
        print('FAIL: %s: %d pixels differ; first at line %d dot %d: %02x vs %02x'
              % (name, len(bad), y, x, vis[y][x], exp[y][x]))
        sys.exit(1)
    print('PASS: %s: INFO_3 %x, feature reads %s; %d x %d displayed pixels equal the '
          'screen rebuilt from the ROM font and VIDEO_PARMS' % (name, got, feat, len(exp[0]), len(exp)))


def main():
    rom = open(sys.argv[2], 'rb').read()
    if sys.argv[1] == 'gen':
        gen(rom, sys.argv[3])
    else:
        check(rom, sys.argv[3])


if __name__ == '__main__':
    main()
