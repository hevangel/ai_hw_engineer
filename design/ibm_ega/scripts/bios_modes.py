#!/usr/bin/env python3
"""BIOS mode-table geometry check for the IBM EGA.

usage: bios_modes.py gen   ROM_CPU_ORDER OUTDIR
       bios_modes.py check ROM_CPU_ORDER OUTDIR

gen: for every one of the 23 entries of the ROM's VIDEO_PARMS table
(0717h, parsed by its documented layout, never typed by hand) write a
script that programs the card exactly as SET_REGS does (listing lines
2479-2587), turns the palette on as PAL_ON does, and runs three frames.

check: from the RTL's dot stream (already proven identical to the model's
by run_sim.sh) measure, for each entry: dots per line, lines per frame,
retrace widths and positions, displayed pixels and lines, and the dot
clock (oscillator, /2). The line and frame rates follow from the measured
counts and the oscillator. They must equal the counts the registers
specify (TR p.25-44 with ASSUMPTION E8), the displayed resolution must
equal TR's mode tables (p.5-7), and the rates must be within 2% of the
display figures TR gives (p.6-7): IBM Color Display 15.75 kHz / 60 Hz,
Enhanced Color Display high resolution 21.85 kHz / 60 Hz, IBM Monochrome
Display 18.43 kHz / 50 Hz. IBM's own register values put mode F (14 MHz
clock, 784-dot lines) and modes 0*/1* (376-dot lines) 0.9-1.5% below those
nominal figures; the table reports every deviation. Writes
OUTDIR/geometry.md.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ega_bios as B  # noqa: E402

OSC = {0: 14318180.0, 1: 16257000.0}

# TR p.5-7 mode tables: entry -> (description, display, resolution)
IBM = {
    0x00: ('mode 0, 40x25 A/N', 'color', (320, 200)),
    0x01: ('mode 1, 40x25 A/N', 'color', (320, 200)),
    0x02: ('mode 2, 80x25 A/N', 'color', (640, 200)),
    0x03: ('mode 3, 80x25 A/N', 'color', (640, 200)),
    0x04: ('mode 4, 320x200 4 colours', 'color', (320, 200)),
    0x05: ('mode 5, 320x200 4 colours', 'color', (320, 200)),
    0x06: ('mode 6, 640x200 2 colours', 'color', (640, 200)),
    0x07: ('mode 7, 80x25 monochrome A/N', 'mono', (720, 350)),
    0x08: ('reserved entry 8', None, None),
    0x09: ('reserved entry 9', None, None),
    0x0A: ('reserved entry A', None, None),
    0x0B: ('font-load set (colour)', None, None),
    0x0C: ('font-load set (monochrome)', None, None),
    0x0D: ('mode D, 320x200 16 colours', 'color', (320, 200)),
    0x0E: ('mode E, 640x200 16 colours', 'color', (640, 200)),
    0x0F: ('mode F, 640x350 mono graphics (64 KB)', 'mono', (640, 350)),
    0x10: ('mode 10, 640x350 (64 KB)', 'enhanced', (640, 350)),
    0x11: ('mode F, 640x350 mono graphics (>64 KB)', 'mono', (640, 350)),
    0x12: ('mode 10, 640x350 16/64 colours (>64 KB)', 'enhanced', (640, 350)),
    0x13: ('mode 0*, 40x25 A/N enhanced', 'enhanced', (320, 350)),
    0x14: ('mode 1*, 40x25 A/N enhanced', 'enhanced', (320, 350)),
    0x15: ('mode 2*, 80x25 A/N enhanced', 'enhanced', (640, 350)),
    0x16: ('mode 3*, 80x25 A/N enhanced', 'enhanced', (640, 350)),
}
RATES = {'color': (15750.0, 60.0), 'enhanced': (21850.0, 60.0), 'mono': (18430.0, 50.0)}


def geometry(ent):
    c = ent['crtc']
    ht = c[0] + 2
    vt = (c[6] | ((c[7] & 1) << 8)) + 2
    w = 8 if ent['seq'][0] & 1 else 9
    div = 2 if ent['seq'][0] & 8 else 1
    return ht, vt, w, div


def gen(rom, out):
    os.makedirs(out, exist_ok=True)
    names = []
    for n in range(23):
        ent = B.entry(rom, n)
        mono = B.is_mono(ent)
        ht, vt, w, div = geometry(ent)
        s = ['# BIOS VIDEO_PARMS entry %02X: %s' % (n, IBM[n][0])]
        s += B.set_regs(ent, mono) + B.pal_on(mono)
        s.append('T %d' % (3 * ht * w * div * vt + 64))
        name = 'entry%02x' % n
        with open(os.path.join(out, name + '.txt'), 'w') as f:
            f.write('\n'.join(s) + '\n')
        names.append(name)
    with open(os.path.join(out, 'list.txt'), 'w') as f:
        f.write('\n'.join(names) + '\n')
    print('wrote %d BIOS mode-table scripts' % len(names))


def measure(path, ent):
    hp, vp = (ent['misc'] >> 6) & 1, (ent['misc'] >> 7) & 1
    pulses = dots = 0
    for ln in open(path):
        if ln.startswith('T '):
            _, n, d = ln.split()
            pulses += int(n)
            dots += int(d)
    fr = B.frames(path, hp, vp)
    full = fr[1:-1]                 # complete frames between retraces
    if not full:
        return None
    f = full[-1]
    body = f[1:-1]                  # complete lines
    llen = sorted(set(len(x) for x in body))
    # retrace widths: horizontal in dots (first complete line), vertical in lines
    hsw = sum(1 for v in body[0] if ((v >> 6) & 1) ^ hp)
    vsl = sum(1 for x in f if ((x[0] >> 7) & 1) ^ vp)
    de_lines = [x for x in f if any((v >> 9) & 1 for v in x)]
    de_w = sorted(set(sum((v >> 9) & 1 for v in x) for x in de_lines))
    return {
        'pulses': pulses, 'dots': dots, 'lines': len(f), 'line_len': llen,
        'hsync_dots': hsw, 'vsync_lines': vsl, 'de_lines': len(de_lines), 'de_w': de_w,
        'frames': len(full),
    }


def check(rom, out):
    rows = []
    fails = []
    for n in range(23):
        ent = B.entry(rom, n)
        ht, vt, w, div = geometry(ent)
        m = measure(os.path.join(out, 'entry%02x.rtl' % n), ent)
        desc, disp, res = IBM[n]
        if m is None:
            fails.append('entry %02X: no complete frame' % n)
            continue
        c = ent['crtc']
        hde = (c[1] + 1) * w
        vde = (c[0x12] | ((c[7] >> 1) & 1) << 8) + 1
        osc = OSC.get((ent['misc'] >> 2) & 3)
        exp_dots = m['pulses'] // div if div == 2 else m['pulses']
        dot_hz = osc / div
        hz = dot_hz / (ht * w)
        vhz = hz / vt
        if disp:
            want_h, want_v = RATES[disp]
            dev = '%s %.2f kHz / %.0f Hz: %+.1f%% / %+.1f%%' % (
                disp, want_h / 1e3, want_v, 100 * (hz - want_h) / want_h,
                100 * (vhz - want_v) / want_v)
        else:
            dev = '(not a display mode in TR)'
        line = ('| %02X | %s | %.5f%s | %d x %d = %d | %d | %d dots | %d | %d x %d |'
                ' %.2f kHz | %.2f Hz | %s |') % (
            n, desc, osc / 1e6, ' /2' if div == 2 else '', ht, w, ht * w, vt,
            m['hsync_dots'], m['vsync_lines'], m['de_w'][0] if m['de_w'] else 0,
            m['de_lines'], hz / 1e3, vhz, dev)
        rows.append(line)
        if m['line_len'] != [ht * w]:
            fails.append('entry %02X: line length %s, registers give %d' % (n, m['line_len'], ht * w))
        if m['lines'] != vt:
            fails.append('entry %02X: %d lines per frame, registers give %d' % (n, m['lines'], vt))
        if abs(m['dots'] - exp_dots) > 1:
            fails.append('entry %02X: %d dots for %d pulses (div %d)' % (n, m['dots'], m['pulses'], div))
        if m['de_w'] != [hde] or m['de_lines'] != vde:
            fails.append('entry %02X: displayed %s x %d, registers give %d x %d'
                         % (n, m['de_w'], m['de_lines'], hde, vde))
        if res is not None:
            if (hde, vde) != res:
                fails.append('entry %02X: resolution %dx%d, TR gives %dx%d' % (n, hde, vde, *res))
            want_h, want_v = RATES[disp]
            if abs(hz - want_h) / want_h > 0.02 or abs(vhz - want_v) / want_v > 0.02:
                fails.append('entry %02X: %.0f Hz / %.2f Hz vs TR %s %.0f / %.0f'
                             % (n, hz, vhz, disp, want_h, want_v))
    hdr = ('| Entry | Mode | Dot clock MHz | Characters x dots = dots/line | Lines/frame |'
           ' HSYNC | VSYNC lines | Displayed | Line rate | Frame rate | vs TR display |\n'
           '|---|---|---|---|---|---|---|---|---|---|---|')
    with open(os.path.join(out, 'geometry.md'), 'w') as f:
        f.write(hdr + '\n' + '\n'.join(rows) + '\n')
    print(hdr)
    print('\n'.join(rows))
    for x in fails:
        print('FAIL: ' + x)
    if fails:
        sys.exit(1)
    print('PASS: 23 BIOS mode-table entries: geometry equals the registers; '
          'resolutions equal TR p.5-7; rates within 2% of TR p.6-7')


def main():
    rom = open(sys.argv[2], 'rb').read()
    if sys.argv[1] == 'gen':
        gen(rom, sys.argv[3])
    else:
        check(rom, sys.argv[3])


if __name__ == '__main__':
    main()
