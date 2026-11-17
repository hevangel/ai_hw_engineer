#!/usr/bin/env python3
"""Helpers derived from the IBM PS/2 Display Adapter BIOS (ROM 10/27/86).

- VIDEO_PARMS parsing: 64-byte entries at C000:1342h, the layout of the EGA
  BIOS listing (VPARMS.INC): columns, rows, points, page length (word),
  sequencer 1-4, Miscellaneous Output, CRTC 00h-18h, attribute 00h-13h,
  graphics 0-8. 29 entries; which entry serves which mode was read from
  the entries themselves (columns/rows/points, clock, memory map) and is
  listed in ENTRIES.
- set_regs(): the port writes of the BIOS SET_REGS routine (C000:1127-1193)
  for one entry, with every word OUT split into its two byte cycles (low
  byte to DX, high byte to DX+1) as the AT bus does for an 8-bit card, plus
  the palette and overscan writes (attribute 00h-0Fh, 11h) and IPAS on.
- frames(): rebuild lines/frames from the run-length dot trace.
"""

TABLE = 0x1342
ENTRY = 64
NENTRIES = 29
FONT_8X8 = 0x378D
FONT_8X14 = 0x3F8D
FONT_8X16 = 0x4EBA
PATCH_9X14 = 0x4D8D
PATCH_9X16 = 0x5EBA

# entry -> (mode, description, vertical size class, VGAXGA Figure 2-4 PELs)
ENTRIES = {
    0x00: ('0', '40x25 A/N 8x8, 200 lines double scanned', 400, (320, 200)),
    0x01: ('1', '40x25 A/N 8x8, 200 lines double scanned', 400, (320, 200)),
    0x02: ('2', '80x25 A/N 8x8, 200 lines double scanned', 400, (640, 200)),
    0x03: ('3', '80x25 A/N 8x8, 200 lines double scanned', 400, (640, 200)),
    0x04: ('4', '320x200 4 colours', 400, (320, 200)),
    0x05: ('5', '320x200 4 colours', 400, (320, 200)),
    0x06: ('6', '640x200 2 colours', 400, (640, 200)),
    0x07: ('7', '80x25 mono A/N 9x14', 350, (720, 350)),
    0x08: ('(8)', 'unused slot (CGA-style 160x200 values)', None, None),
    0x09: ('(9)', 'empty slot (all zero)', None, None),
    0x0A: ('(A)', 'unused slot (EGA mode 0 values)', None, None),
    0x0B: ('(B)', 'reserved / font-load set', None, None),
    0x0C: ('(C)', 'reserved / font-load set', None, None),
    0x0D: ('D', '320x200 16 colours', 400, (320, 200)),
    0x0E: ('E', '640x200 16 colours', 400, (640, 200)),
    0x0F: ('F (64K)', '640x350 mono graphics, 64 KB values', None, None),
    0x10: ('10 (64K)', '640x350 16 colours, 64 KB values', None, None),
    0x11: ('F', '640x350 mono graphics', 350, (640, 350)),
    0x12: ('10', '640x350 16 colours', 350, (640, 350)),
    0x13: ('0*', '40x25 A/N 8x14', 350, (320, 350)),
    0x14: ('1*', '40x25 A/N 8x14', 350, (320, 350)),
    0x15: ('2*', '80x25 A/N 8x14', 350, (640, 350)),
    0x16: ('3*', '80x25 A/N 8x14', 350, (640, 350)),
    0x17: ('0+/1+', '40x25 A/N 9x16', 400, (360, 400)),
    0x18: ('2+/3+', '80x25 A/N 9x16', 400, (720, 400)),
    0x19: ('7+', '80x25 mono A/N 9x16', 400, (720, 400)),
    0x1A: ('11', '640x480 2 colours', 480, (640, 480)),
    0x1B: ('12', '640x480 16 colours', 480, (640, 480)),
    0x1C: ('13', '320x200 256 colours', 400, (320, 200)),
}


def entry(rom, n):
    e = rom[TABLE + ENTRY * n: TABLE + ENTRY * (n + 1)]
    return {
        'cols': e[0], 'rows': e[1], 'points': e[2],
        'page': e[3] | (e[4] << 8),
        'seq': list(e[5:9]), 'misc': e[9], 'crtc': list(e[10:35]),
        'attr': list(e[35:55]), 'gc': list(e[55:64]), 'raw': e,
    }


def ow(p, v):
    return 'OW %03x %02x' % (p, v & 0xFF)


def oww(p, ax):
    """OUT DX,AX to the 8-bit card: two byte cycles."""
    return [ow(p, ax & 0xFF), ow(p + 1, ax >> 8)]


def enable_card():
    """POST card enable (C000:0096-00AA): 46E8h = 16h (setup), 102h = 01h,
    46E8h = 0Eh (enable); word OUTs split into byte cycles."""
    return oww(0x46E8, 0x0016) + oww(0x0102, 0x0001) + oww(0x46E8, 0x000E)


def set_regs(ent, mono=None):
    if mono is None:
        mono = not (ent['misc'] & 1)
    crt = 0x3B4 if mono else 0x3D4
    st = crt + 6
    s = oww(0x3C4, 0x0100)                              # synchronous reset
    for i, v in enumerate(ent['seq'], 1):
        s += oww(0x3C4, (v << 8) | i)
    s += [ow(0x3C2, ent['misc'])]
    s += oww(0x3C4, 0x0300)                             # run
    s += oww(crt, 0x0011)                               # clear Protect
    for i, v in enumerate(ent['crtc']):
        s += oww(crt, (v << 8) | i)
    s += ['OR %03x' % st]
    for i in list(range(16)) + [0x10, 0x11, 0x12, 0x13, 0x14]:
        v = ent['attr'][i] if i < 0x14 else 0
        s += [ow(0x3C0, i), ow(0x3C0, v)]
    for i, v in enumerate(ent['gc']):
        s += oww(0x3CE, (v << 8) | i)
    s += ['OR %03x' % st, ow(0x3C0, 0x20)]             # palette on (IPAS)
    return s


def read_trace_dots(path):
    for ln in open(path):
        if ln.startswith('V '):
            _, c, v = ln.split()
            yield int(c), int(v, 16)


HS, VS, BL, DE = 18, 19, 20, 21


def lines_from_runs(runs, hpol, vpol):
    """Lines start at the dot after a falling edge of horizontal retrace."""
    lines, cur, prev_h = [], [], 0
    for c, v in runs:
        h = ((v >> HS) & 1) ^ hpol
        for _ in range(c):
            if prev_h and not h:
                lines.append(cur)
                cur = []
            cur.append(v)
            prev_h = h
    if cur:
        lines.append(cur)
    return lines


def frames(path, hpol, vpol):
    lines = lines_from_runs(read_trace_dots(path), hpol, vpol)
    fr, cur, prev_v = [], [], 0
    for ln in lines:
        v = ((ln[0] >> VS) & 1) ^ vpol
        if prev_v and not v and cur:
            fr.append(cur)
            cur = []
        cur.append(ln)
        prev_v = v
    fr.append(cur)
    return fr
