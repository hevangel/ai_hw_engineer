#!/usr/bin/env python3
"""Helpers derived from the IBM EGA BIOS listing (TR pp.103 ff.).

- VIDEO_PARMS parsing: the 64-byte entry layout documented at listing
  lines 1771-1779 (VPARMS.INC): columns, rows, points, page length (word),
  sequencer registers 1-4, Miscellaneous Output, CRTC 00h-18h, attribute
  00h-13h, graphics 0-8. Table at 0717h, 23 entries; entry selection as in
  MAKE_BASE (listing lines 2422-2475).
- set_regs(): the port writes of SET_REGS (listing lines 2479-2587) for one
  entry, as bench script lines.
- frames(): rebuild lines/frames from the run-length dot trace written by
  tb/ega_tb.cpp and scripts/ega_model.py (frame-capture contract).
"""

TABLE = 0x0717
ENTRY = 64
FONT_8X14 = 0x2230      # CGMN (listing line 5663; 'A' at 25C0h)
FONT_8X8 = 0x3160       # CGDDOT (INT 1Fh vector 3560h = its upper half)


def entry(rom, n):
    e = rom[TABLE + ENTRY * n: TABLE + ENTRY * (n + 1)]
    return {
        'cols': e[0], 'rows': e[1], 'points': e[2],
        'page': e[3] | (e[4] << 8),
        'seq': list(e[5:9]), 'misc': e[9], 'crtc': list(e[10:35]),
        'attr': list(e[35:55]), 'gc': list(e[55:64]), 'raw': e,
    }


def entry_index(mode, ext_mem=True, enhanced=False):
    """MAKE_BASE: memory expansion selects 11h/12h for modes F/10h; the
    enhanced switch settings (03h/09h) select 13h+mode for modes 0-3."""
    if ext_mem and mode == 0x0F:
        return 0x11
    if ext_mem and mode == 0x10:
        return 0x12
    if mode <= 3 and enhanced:
        return 0x13 + mode
    return mode


def set_regs(ent, mono):
    """SET_REGS port writes (listing 2484-2586) as script lines."""
    crt = 0x3B4 if mono else 0x3D4
    st = 0x3BA if mono else 0x3DA
    s = ['OW 3c4 00', 'OW 3c5 01']                      # reset sequencer
    for i, v in enumerate(ent['seq'], 1):
        s += ['OW 3c4 %02x' % i, 'OW 3c5 %02x' % v]
    s += ['OW 3c2 %02x' % ent['misc']]
    s += ['OW 3c4 00', 'OW 3c5 03']                     # start sequencer
    for i, v in enumerate(ent['crtc']):
        s += ['OW %03x %02x' % (crt, i), 'OW %03x %02x' % (crt + 1, v)]
    s += ['OR %03x' % st]                               # IN AL,DX (WHAT_BASE)
    for i, v in enumerate(ent['attr']):
        s += ['OW 3c0 %02x' % i, 'OW 3c0 %02x' % v]
    s += ['OW 3cc 00', 'OW 3ca 01']
    for i, v in enumerate(ent['gc']):
        s += ['OW 3ce %02x' % i, 'OW 3cf %02x' % v]
    return s


def read_trace_dots(path):
    """Yield (count, value) runs from all T blocks of a trace."""
    for ln in open(path):
        if ln.startswith('V '):
            _, c, v = ln.split()
            yield int(c), int(v, 16)


def lines_from_runs(runs, hpol, vpol):
    """Split the dot stream into lines at each falling edge of horizontal
    retrace (polarity removed). Returns list of (line_dots, vsync_flag)."""
    lines = []
    cur = []
    prev_h = 0
    for c, v in runs:
        h = ((v >> 6) & 1) ^ hpol
        vs = ((v >> 7) & 1) ^ vpol
        for _ in range(c):
            if prev_h and not h:
                lines.append(cur)
                cur = []
            cur.append(v)
            prev_h = h
    if cur:
        lines.append(cur)
    return lines
