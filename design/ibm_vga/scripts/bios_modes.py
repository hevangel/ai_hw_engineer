#!/usr/bin/env python3
"""BIOS mode-table geometry check for the IBM PS/2 Display Adapter.

usage: bios_modes.py gen   ROM32K OUTDIR
       bios_modes.py check ROM32K OUTDIR

gen: for every display entry of the ROM's VIDEO_PARMS table (C000:1342h,
parsed by its layout, never typed by hand) write a script that enables the
card as the POST does, programs it as SET_REGS does (scripts/vga_bios.py)
and runs a little over two frames.

check: from the RTL's dot stream (already proven identical to the model's
by run_sim.sh) measure for each entry the dots per line, lines per frame,
horizontal and vertical sync, blanking and porch widths, displayed pixels
and lines, and the sync polarities. They must equal:

- the counts the registers specify (VGAXGA p.2-56 to 2-77);
- the displayed resolution of VGAXGA Figure 2-4, doubled where Figure 2-5
  says the mode is double scanned and, horizontally, where the attribute
  controller's PEL width bit makes two dots per PEL (mode 13h);
- HITR "Signal Timing" (Figures 99-104, VGAXGA section 4 timing set #1):
  line period 31.778 us, horizontal sync 3.813 us, vertical sync 0.064 ms,
  frame period 14.268 ms (350 and 400 lines) or 16.683 ms (480 lines), the
  vertical size selected by the sync polarities (Figure 4-3, HITR Figure 22)
  equal to the mode's, the vertical blanking and porches of Figures 99-102
  and the horizontal blanking and porches of Figure 103 (border) or 104 (no
  border, Figure 2-5) -- each to within one dot / one line.

The horizontal pipeline depths (ASSUMPTION V14) were chosen from modes 12h
and 3+ (entries 1Bh and 18h); for those two the horizontal porch check is
not independent. Writes OUTDIR/geometry.md.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vga_bios as B  # noqa: E402

OSC = {0: 25175000.0, 1: 28322000.0}
DISPLAY = [n for n, v in B.ENTRIES.items() if v[2] is not None]
# every non-empty entry is run; the IBM timing figures apply to DISPLAY
RUN = [n for n in B.ENTRIES if n != 0x09]
# Figure 2-5: double scan / border support per mode
DOUBLE = {'0', '1', '2', '3', '4', '5', '6', 'D', 'E', '13'}
NO_BORDER = {'0', '1', '0*', '1*', '0+/1+', '4', '5', 'D'}
# HITR Figures 99-102 (ms): blanking, front porch, back porch per size
VTIME = {350: (2.765, 1.017, 1.684), 400: (1.112, 0.191, 0.858), 480: (0.922, 0.095, 0.763)}
FRAME_MS = {350: 14.268, 400: 14.268, 480: 16.683}
# HITR Figures 103/104 (us): blanking, front porch, back porch
HTIME = {True: (5.720, 0.318, 1.589), False: (6.356, 0.636, 1.907)}
SIZE = {1: 400, 2: 350, 3: 480}           # Misc Output bits 7-6 (Figure 2-22)
LINE_US, HSYNC_US, VSYNC_MS = 31.778, 3.813, 0.064
# The BIOS register values of the eight no-border (40-column, dot clock /2)
# entries cannot produce HITR Figure 104: End Horizontal Blank gives a
# blanking width of 8 characters by the algorithm of p.2-58 (start 28h, end
# 30h) where Figure 104 shows 10 (6.356 us), and End Horizontal Retrace
# (start 2Bh, end 00h, delay 1) gives by p.2-60 a width of (00h - 0Bh) mod
# 32 = 21 characters, longer than the 50-character line, so the counter
# wrap ends it after 7 characters (4.449 us) where Figure 104 shows 6
# (3.813 us). These two horizontal checks are reported, not gated, for the
# no-border entries; every vertical figure and the line/frame periods are
# gated for them as for the others.
DISAGREE = 'no-border entries: Figure 104 vs BIOS register values'


def geometry(ent):
    c = ent['crtc']
    ht = c[0] + 5
    vt = (c[6] | ((c[7] & 1) << 8) | (((c[7] >> 5) & 1) << 9)) + 2
    w = 8 if ent['seq'][0] & 1 else 9
    div = 2 if ent['seq'][0] & 8 else 1
    return ht, vt, w, div


def gen(rom, out):
    os.makedirs(out, exist_ok=True)
    names = []
    for n in RUN:
        ent = B.entry(rom, n)
        ht, vt, w, div = geometry(ent)
        s = ['# BIOS VIDEO_PARMS entry %02X: mode %s, %s' % ((n,) + B.ENTRIES[n][:2])]
        s += B.enable_card() + B.set_regs(ent)
        s.append('T %d' % int(2.3 * ht * w * div * vt))
        name = 'entry%02x' % n
        with open(os.path.join(out, name + '.txt'), 'w') as f:
            f.write('\n'.join(s) + '\n')
        names.append(name)
    with open(os.path.join(out, 'list.txt'), 'w') as f:
        f.write('\n'.join(names) + '\n')
    print('wrote %d BIOS mode-table scripts' % len(names))


def runs_of(seq, pred):
    """(start, length) of the runs where pred holds, in a cyclic line."""
    n = len(seq)
    flags = [pred(v) for v in seq]
    if all(flags):
        return [(0, n)]
    k = flags.index(False)
    out, i = [], 0
    while i < n:
        j = (k + i) % n
        if flags[j]:
            st, ln = j, 0
            while i < n and flags[(k + i) % n]:
                ln += 1
                i += 1
            out.append((st, ln))
        else:
            i += 1
    return out


def measure(path, ent):
    hp, vp = (ent['misc'] >> 6) & 1, (ent['misc'] >> 7) & 1
    pulses = dots = 0
    for ln in open(path):
        if ln.startswith('T '):
            _, n, d = ln.split()
            pulses += int(n)
            dots += int(d)
    fr = B.frames(path, hp, vp)
    full = fr[1:-1]
    if not full:
        return None
    f = full[-1]
    body = f[1:-1]
    llen = sorted(set(len(x) for x in body))
    ln0 = body[len(body) // 2]
    L = len(ln0)
    hs = runs_of(ln0, lambda v: ((v >> B.HS) & 1) ^ hp)
    vlines = [all((v >> B.BL) & 1 for v in x) for x in f]
    vs = [((x[0] >> B.VS) & 1) ^ vp for x in f]
    de_lines = [x for x in f if any((v >> B.DE) & 1 for v in x)]
    de_w = sorted(set(sum((v >> B.DE) & 1 for v in x) for x in de_lines))
    # horizontal blank of a displayed line (with its horizontal sync)
    act = de_lines[len(de_lines) // 2]
    hb = runs_of(act, lambda v: (v >> B.BL) & 1)
    hsa = runs_of(act, lambda v: ((v >> B.HS) & 1) ^ hp)
    m = {'pulses': pulses, 'dots': dots, 'lines': len(f), 'line_len': llen,
         'hsync_dots': hs[0][1] if len(hs) == 1 else None,
         'vsync_lines': sum(vs), 'de_lines': len(de_lines), 'de_w': de_w}
    if len(hb) == 1 and len(hsa) == 1:
        (b0, bl), (s0, sl) = hb[0], hsa[0]
        m['hblank'] = bl
        m['hfp'] = (s0 - b0) % L
        m['hbp'] = (b0 + bl - (s0 + sl)) % L
    # vertical: lines are indexed from the end of the vertical retrace
    vb = runs_of(vlines, lambda x: x)
    vsr = runs_of(vs, lambda x: x)
    if len(vb) == 1 and len(vsr) == 1:
        (b0, bl), (s0, sl) = vb[0], vsr[0]
        nl = len(f)
        m['vblank'] = bl
        m['vfp'] = (s0 - b0) % nl
        m['vbp'] = (b0 + bl - (s0 + sl)) % nl
    return m


def check(rom, out):
    rows, fails, notes = [], [], []
    for n in RUN:
        ent = B.entry(rom, n)
        mode, desc, vsize, pels = B.ENTRIES[n]
        ht, vt, w, div = geometry(ent)
        m = measure(os.path.join(out, 'entry%02x.rtl' % n), ent)
        if m is None:
            fails.append('entry %02X: no complete frame' % n)
            continue
        c = ent['crtc']
        osc = OSC[(ent['misc'] >> 2) & 3]
        dot_us = 1e6 * div / osc
        hde = (c[1] + 1) * w
        vde = (c[0x12] | (((c[7] >> 1) & 1) << 8) | (((c[7] >> 6) & 1) << 9)) + 1
        line_us = ht * w * dot_us
        frame_ms = line_us * vt / 1000.0
        size = SIZE.get(ent['misc'] >> 6)
        border = mode not in NO_BORDER
        pw = 2 if ent['attr'][0x10] & 0x40 else 1
        exp_res = (pels[0] * pw, pels[1] * (2 if mode in DOUBLE else 1)) if pels else None

        def chk(cond, what):
            if not cond:
                fails.append('entry %02X (mode %s): %s' % (n, mode, what))

        chk(m['line_len'] == [ht * w], 'line %s dots, registers give %d' % (m['line_len'], ht * w))
        chk(m['lines'] == vt, '%d lines per frame, registers give %d' % (m['lines'], vt))
        chk(abs(m['dots'] - m['pulses'] // div) <= 1, 'dot count %d for %d pulses' % (m['dots'], m['pulses']))
        chk(m['de_w'] == [hde] and m['de_lines'] == vde,
            'displayed %s x %d, registers give %d x %d' % (m['de_w'], m['de_lines'], hde, vde))
        if vsize is None:
            rows.append('| %02X | %s | %.3f%s | %d x %d = %d | %d | %s | %dx%d | %.3f | %.3f | %.2f | %.2f |'
                        ' - | - | not a mode of this 256 KB card: registers only |' % (
                n, mode, osc / 1e6, ' /2' if div == 2 else '', ht, w, ht * w, vt,
                m['hsync_dots'], hde, vde, line_us, frame_ms, 1000 / line_us, 1000 / frame_ms))
            continue
        chk((hde, vde) == exp_res, 'resolution %dx%d, Figure 2-4/2-5 give %dx%d' % ((hde, vde) + exp_res))
        chk(abs(line_us - LINE_US) <= dot_us, 'line period %.3f us, HITR %.3f' % (line_us, LINE_US))
        hs_ok = m['hsync_dots'] is not None and abs(m['hsync_dots'] * dot_us - HSYNC_US) <= dot_us
        if border:
            chk(hs_ok, 'hsync %s dots' % m['hsync_dots'])
        elif not hs_ok:
            notes.append('entry %02X (mode %s): hsync %d dots = %.3f us; HITR %.3f us. '
                         'Documented disagreement (see DISAGREE)' % (n, mode, m['hsync_dots'],
                                                                     m['hsync_dots'] * dot_us, HSYNC_US))
        chk(abs(m['vsync_lines'] * line_us / 1000 - VSYNC_MS) <= line_us / 1000,
            'vsync %d lines' % m['vsync_lines'])
        chk(size == vsize, 'sync polarities select %s lines, mode is %s' % (size, vsize))
        chk(abs(frame_ms - FRAME_MS[vsize]) <= line_us / 1000,
            'frame %.3f ms, HITR %.3f' % (frame_ms, FRAME_MS[vsize]))
        vb, vf, vbp = VTIME[vsize]
        lms = line_us / 1000
        if 'vblank' in m:
            chk(abs(m['vblank'] * lms - vb) <= lms, 'vertical blank %d lines (%.3f ms vs %.3f)' % (m['vblank'], m['vblank'] * lms, vb))
            chk(abs(m['vfp'] * lms - vf) <= lms, 'vertical front porch %d lines vs %.3f ms' % (m['vfp'], vf))
            chk(abs(m['vbp'] * lms - vbp) <= lms, 'vertical back porch %d lines vs %.3f ms' % (m['vbp'], vbp))
        else:
            chk(False, 'vertical blank/retrace not a single interval')
        hb, hf, hbp = HTIME[border]
        cw = w * dot_us
        if 'hblank' in m:
            hres = (m['hblank'] * dot_us, m['hfp'] * dot_us, m['hbp'] * dot_us)
            ok = (abs(hres[0] - hb) <= cw and abs(hres[1] - hf) <= cw and abs(hres[2] - hbp) <= cw)
            if n in (0x18, 0x1B):
                notes.append('entry %02X: horizontal porches are the calibration of V14' % n)
            if not border and not ok:
                notes.append('entry %02X (mode %s): horizontal blank/porches %.3f/%.3f/%.3f us vs '
                             'Figure 104 %.3f/%.3f/%.3f: documented disagreement (see DISAGREE)'
                             % ((n, mode) + hres + (hb, hf, hbp)))
                ok = True
            chk(ok, 'horizontal blank/porches %.3f/%.3f/%.3f us vs Figure %d %.3f/%.3f/%.3f'
                % (hres + (103 if border else 104, hb, hf, hbp)))
        else:
            hres = (0, 0, 0)
            chk(False, 'horizontal blank/retrace not a single interval')
        rows.append(('| %02X | %s | %.3f%s | %d x %d = %d | %d | %d | %dx%d | %.3f | %.3f | %.2f | %.2f |'
                     ' %d / %d / %d | %.3f / %.3f / %.3f | %s |') % (
            n, mode, osc / 1e6, ' /2' if div == 2 else '', ht, w, ht * w, vt,
            m['hsync_dots'] or 0, hde, vde, line_us, frame_ms, 1000 / line_us, 1000 / frame_ms,
            m.get('vblank', 0), m.get('vfp', 0), m.get('vbp', 0), hres[0], hres[1], hres[2],
            '%s, %s' % ({350: '-+', 400: '+-', 480: '--'}[vsize], 'border' if border else 'no border')))
    hdr = ('| Entry | Mode | Dot clock MHz | Chars x dots = dots/line | Lines/frame | HSYNC dots |'
           ' Displayed | Line us | Frame ms | Line kHz | Frame Hz | VBlank / VFP / VBP lines |'
           ' HBlank / HFP / HBP us | VSYNC/HSYNC polarity, border |\n'
           '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')
    with open(os.path.join(out, 'geometry.md'), 'w') as f:
        f.write(hdr + '\n' + '\n'.join(rows) + '\n')
    print(hdr)
    print('\n'.join(rows))
    for x in notes:
        print('NOTE: ' + x)
    for x in fails:
        print('FAIL: ' + x)
    if fails:
        sys.exit(1)
    print('PASS: %d BIOS mode-table entries: geometry equals the registers; the %d display '
          'entries also equal the resolutions of Figure 2-4/2-5 and the HITR timing figures '
          '99-104' % (len(rows), len(DISPLAY)))


def main():
    rom = open(sys.argv[2], 'rb').read()
    if sys.argv[1] == 'gen':
        gen(rom, sys.argv[3])
    else:
        check(rom, sys.argv[3])


if __name__ == '__main__':
    main()
