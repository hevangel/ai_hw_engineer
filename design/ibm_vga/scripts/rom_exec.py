#!/usr/bin/env python3
"""Execute the IBM PS/2 Display Adapter BIOS with Unicorn and replay its
bus traffic on the RTL and the model.

usage: rom_exec.py gen   ROM32K OUTDIR
       rom_exec.py check ROM32K OUTDIR/<name>

gen runs the ROM's own code in Unicorn (x86 real mode) against the
reference model (scripts/vga_model.py) standing in for the card, inside a
minimal PC: 640 KB RAM, an interrupt vector table whose system vectors point
at an IRET stub, an 8253 PIT channel 0 (the POST measures the frame time
with it) and the speaker port (error beeps). Every I/O cycle the CPU makes
outside the system board (port 100h and above) and every memory cycle to
A0000h-BFFFFh goes through the card's 8-bit slot as byte cycles (a word
access is two byte cycles, low address first) and is written to a bench
script with the value the model returned, together with "T n" lines that
carry the elapsed time in oscillator pulses. Time is virtual: 0.25 us per
executed basic block, 1 us per I/O cycle and 0.5 us per card memory cycle.
The ROM itself is mapped as plain memory (code and font fetches are not
replayed through the card; the card's ROM decode has its own tests).

Scenarios (one script each, listed in OUTDIR/exec_list.txt):
  exec_post_color  POST with a colour display load (load_i = 111b), which
                   ends with the BIOS's own INT 10h mode 3 set (9x16, 400
                   lines); then a text screen and two frames
  exec_post_mono   POST with a monochrome display load (010b)
  exec_post_none   POST with no display (000b)
  exec_mode12      colour POST, INT 10h AX=0012h, a 16-colour test pattern
  exec_mode13      colour POST, INT 10h AX=0013h, a 256-colour test pattern

run_sim.sh replays each script on the model (every recorded read value is
an expectation the full-detail model must meet) and on the RTL (trace equal
to the model's). check then verifies, from the RTL trace and the ROM:
- the POST result: no error beep (C000:0590 never called), the BIOS data
  area display type (40:87h/88h/89h, equipment bits 40:10h) recorded;
- for the colour, mode 12h and mode 13h runs, the picture of the last
  complete frame pixel for pixel against an image rebuilt independently of
  the model: glyphs from the ROM's 8x16 font and 9x16 patch table, the
  attribute/palette registers from the ROM's VIDEO_PARMS entry, and the DAC
  colours from the 3C8h/3C9h writes the BIOS made (in the script);
- the picture is also written as a PPM image to work/img/.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vga_bios as B  # noqa: E402
import vga_model as VM  # noqa: E402

PULSE_HZ = {0: 25175000.0, 1: 28322000.0, 2: 0.0, 3: 0.0}
BLOCK_US, IO_US, MEM_US = 0.25, 1.0, 0.5
STUB_SEG, IRET_OFF, RET_OFF = 0xF000, 0xFF00, 0xFF10
SCEN = {
    'exec_post_color': (7, None),
    'exec_post_mono': (2, None),
    'exec_post_none': (0, None),
    'exec_mode12': (7, 0x12),
    'exec_mode13': (7, 0x13),
}


class PC:
    def __init__(self, rom, load):
        from unicorn import UC_ARCH_X86, UC_HOOK_BLOCK, UC_HOOK_CODE, UC_HOOK_INSN, UC_HOOK_INTR, UC_MODE_16, Uc
        from unicorn import x86_const as X
        self.X = X
        self.card = VM.VGA(rom)
        self.card.fast = True
        self.card.load = load
        self.lines = ['LOAD %x' % load]
        self.t_us = 0.0
        self.t_done = 0.0               # time already emitted as pulses
        self.pit = {'load': 0, 'start': 0.0, 'latch': None, 'rd': 0, 'wr': 0, 'mode': 0}
        self.beeps = []
        self.int_calls = []
        self.foreign = {}
        uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc = uc
        uc.mem_map(0x00000, 0xA0000)
        uc.mmio_map(0xA0000, 0x20000, self.mem_rd, None, self.mem_wr, None)
        uc.mem_map(0xC0000, 0x8000)
        uc.mem_write(0xC0000, bytes(rom[:0x8000]))
        uc.mem_map(0xC8000, 0x38000)
        stub = bytearray(0x10000)
        stub[IRET_OFF] = 0xCF                     # IRET
        stub[RET_OFF] = 0xF4                      # HLT (end marker)
        uc.mem_write(0xF0000, bytes(stub))
        ivt = b''.join((IRET_OFF).to_bytes(2, 'little') + STUB_SEG.to_bytes(2, 'little')
                       for _ in range(256))
        uc.mem_write(0, ivt)
        uc.hook_add(UC_HOOK_INSN, self.port_in, None, 1, 0, X.UC_X86_INS_IN)
        uc.hook_add(UC_HOOK_INSN, self.port_out, None, 1, 0, X.UC_X86_INS_OUT)
        uc.hook_add(UC_HOOK_BLOCK, self.block)
        uc.hook_add(UC_HOOK_INTR, self.intr)
        uc.hook_add(UC_HOOK_CODE, self.beep_hook, None, 0xC0590, 0xC0590)
        uc.hook_add(UC_HOOK_CODE, self.stub_hook, None, 0xFFF00, 0xFFF00)

    # --------------------------------------------------------------- time
    def sync(self):
        """Advance the card to the current virtual time and emit 'T n'."""
        hz = PULSE_HZ[(self.card.misc >> 2) & 3] or PULSE_HZ[0]
        n = int((self.t_us - self.t_done) * hz / 1e6)
        if n > 0:
            for _ in range(n):
                self.card.pulse()
            self.lines.append('T %d' % n)
            self.t_done += n * 1e6 / hz

    def intr(self, uc, intno, ud):
        """Real-mode INT n: Unicorn reports it; vector through the IVT."""
        X = self.X
        ip = uc.reg_read(X.UC_X86_REG_IP)
        cs = uc.reg_read(X.UC_X86_REG_CS)
        fl = uc.reg_read(X.UC_X86_REG_EFLAGS) & 0xFFFF
        ss = uc.reg_read(X.UC_X86_REG_SS)
        sp = uc.reg_read(X.UC_X86_REG_SP)
        for w in (fl, cs, ip):
            sp = (sp - 2) & 0xFFFF
            uc.mem_write(ss * 16 + sp, w.to_bytes(2, 'little'))
        uc.reg_write(X.UC_X86_REG_SP, sp)
        uc.reg_write(X.UC_X86_REG_EFLAGS, fl & ~0x0300)
        v = int.from_bytes(uc.mem_read(4 * intno, 4), 'little')
        uc.reg_write(X.UC_X86_REG_CS, v >> 16)
        uc.reg_write(X.UC_X86_REG_IP, v & 0xFFFF)

    def block(self, uc, addr, size, ud):
        self.t_us += BLOCK_US

    def beep_hook(self, uc, addr, size, ud):
        sp = uc.reg_read(self.X.UC_X86_REG_SP)
        ss = uc.reg_read(self.X.UC_X86_REG_SS)
        ret = int.from_bytes(uc.mem_read(ss * 16 + sp, 2), 'little')
        self.beeps.append((uc.reg_read(self.X.UC_X86_REG_DX), ret))

    def stub_hook(self, uc, addr, size, ud):
        # an interrupt that reached the system stub: record the vector
        sp = uc.reg_read(self.X.UC_X86_REG_SP)
        ss = uc.reg_read(self.X.UC_X86_REG_SS)
        ret = int.from_bytes(uc.mem_read(ss * 16 + sp, 4), 'little')
        self.int_calls.append(('%04x:%04x' % (ret >> 16, ret & 0xFFFF),
                               uc.reg_read(self.X.UC_X86_REG_AX)))

    # ------------------------------------------------------------- ports
    def pit_count(self):
        ticks = int((self.t_us - self.pit['start']) * 1.193182)
        return (self.pit['load'] - ticks) % 65536 if self.pit['load'] else (65536 - ticks) % 65536

    def port_in(self, uc, port, size, ud):
        v = 0
        for k in range(size):
            v |= self.in8((port + k) & 0xFFFF) << (8 * k)
        return v

    def port_out(self, uc, port, size, value, ud):
        for k in range(size):
            self.out8((port + k) & 0xFFFF, (value >> (8 * k)) & 0xFF)

    def in8(self, p):
        self.t_us += IO_US
        if p == 0x40:
            c = self.pit['latch'] if self.pit['latch'] is not None else self.pit_count()
            b = (c >> (8 * self.pit['rd'])) & 0xFF
            self.pit['rd'] ^= 1
            if self.pit['rd'] == 0:
                self.pit['latch'] = None
            return b
        if p == 0x61:
            return 0x00
        if p < 0x100:
            self.foreign[p] = self.foreign.get(p, 0) + 1
            return 0xFF
        self.sync()
        v = self.card.io_read(p)
        self.lines.append('OR %03x %s' % (p, 'Z' if v is None else '%02x' % v))
        return 0xFF if v is None else v

    def out8(self, p, v):
        self.t_us += IO_US
        if p == 0x43:
            if (v & 0xC0) == 0 and (v & 0x30) == 0:
                self.pit['latch'] = self.pit_count()
                self.pit['rd'] = 0
            elif (v & 0xC0) == 0:
                self.pit['mode'] = v
                self.pit['wr'] = 0
            return
        if p == 0x40:
            if self.pit['wr'] == 0:
                self.pit['lo'] = v
                self.pit['wr'] = 1
            else:
                self.pit['load'] = self.pit['lo'] | (v << 8)
                self.pit['start'] = self.t_us
                self.pit['wr'] = 0
            return
        if p < 0x100:
            self.foreign[p] = self.foreign.get(p, 0) + 1
            return
        self.sync()
        self.card.io_write(p, v)
        self.lines.append('OW %03x %02x' % (p, v))

    # ------------------------------------------------------------ memory
    def mem_rd(self, uc, off, size, ud):
        v = 0
        for k in range(size):
            a = 0xA0000 + off + k
            self.t_us += MEM_US
            self.sync()
            b = self.card.mem_read(a)
            self.lines.append('MR %05x %s' % (a, 'Z' if b is None else '%02x' % b))
            v |= (0xFF if b is None else b) << (8 * k)
        return v

    def mem_wr(self, uc, off, size, value, ud):
        for k in range(size):
            a = 0xA0000 + off + k
            self.t_us += MEM_US
            self.sync()
            b = (value >> (8 * k)) & 0xFF
            self.card.mem_write(a, b)
            self.lines.append('MW %05x %02x' % (a, b))

    # --------------------------------------------------------------- run
    def far_call(self, seg, off, regs=None, intr=False):
        X = self.X
        uc = self.uc
        sp = 0x7000
        frame = []
        if intr:
            frame = [0x0202]                      # FLAGS (IF set)
        frame += [STUB_SEG, RET_OFF]
        for w in frame:
            sp -= 2
            uc.mem_write(sp, w.to_bytes(2, 'little'))
        uc.reg_write(X.UC_X86_REG_SS, 0)
        uc.reg_write(X.UC_X86_REG_SP, sp)
        uc.reg_write(X.UC_X86_REG_DS, 0)
        uc.reg_write(X.UC_X86_REG_ES, 0)
        for r, v in (regs or {}).items():
            uc.reg_write(getattr(X, 'UC_X86_REG_' + r), v)
        uc.reg_write(X.UC_X86_REG_CS, seg)
        uc.reg_write(X.UC_X86_REG_IP, off)
        uc.emu_start(seg * 16 + off, STUB_SEG * 16 + RET_OFF, count=200_000_000)
        self.sync()

    def int10(self, ax, **regs):
        v = int.from_bytes(self.uc.mem_read(0x40, 4), 'little')
        r = {'AX': ax}
        r.update(regs)
        self.far_call(v >> 16, v & 0xFFFF, r, intr=True)

    def bda(self, a, n=1):
        return int.from_bytes(self.uc.mem_read(0x400 + a, n), 'little')

    def card_write(self, a, v):
        self.card.mem_write(a, v)
        self.lines.append('MW %05x %02x' % (a, v))

    def card_out(self, p, v):
        self.card.io_write(p, v)
        self.lines.append('OW %03x %02x' % (p, v))


TEXT = [(0, 0, 'IBM PS/2 Display Adapter - BIOS executed in Unicorn', 0x07),
        (1, 0, 'Bright white on blue', 0x1F), (2, 4, 'Yellow on red', 0x4E),
        (3, 0, ''.join(chr(c) for c in range(0xB0, 0xE0)), 0x0F),
        (4, 2, 'Reverse 70h', 0x70), (5, 0, 'MWmw 9-dot patches', 0x0A), (24, 60, 'last row', 0x0E)]


def text_cells():
    cells = {}
    for r, c, s, a in TEXT:
        for i, ch in enumerate(s):
            cells[(r, c + i)] = (ord(ch) & 0xFF, a)
    return cells


def gen(rom, out):
    os.makedirs(out, exist_ok=True)
    names = []
    for name, (load, mode) in SCEN.items():
        pc = PC(rom, load)
        pc.far_call(0xC000, 0x0003)               # option ROM initialization
        post = {'beeps': list(pc.beeps), '487': pc.bda(0x87), '488': pc.bda(0x88),
                '489': pc.bda(0x89), '410': pc.bda(0x10), '449': pc.bda(0x49),
                'ints': sorted(set(i[1] >> 8 for i in pc.int_calls)),
                'foreign': sorted(pc.foreign)}
        ent = None
        if name == 'exec_post_color':
            # text written as the BIOS write routines store it (character at
            # even, attribute at odd addresses of B8000h); cursor off
            for (r, c), (ch, a) in sorted(text_cells().items()):
                o = 2 * (r * 80 + c)
                pc.card_write(0xB8000 + o, ch)
                pc.card_write(0xB8000 + o + 1, a)
            base = 0x3D4
            pc.card_out(base, 0x0A)
            pc.card_out(base + 1, 0x20)
            ent = 0x18
        elif mode == 0x12:
            pc.int10(0x0012)
            # 16 vertical bands of 40 pixels: write mode 0 through the map
            # mask (Set/Reset off), one colour per band, all 480 lines
            pc.card_out(0x3CE, 0x08)
            pc.card_out(0x3CF, 0xFF)
            pc.card_out(0x3C4, 0x02)
            for m in range(4):
                pc.card_out(0x3C5, 1 << m)
                for y in range(480):
                    for xb in range(80):
                        col = (xb * 8) // 40
                        pc.card_write(0xA0000 + y * 80 + xb, 0xFF if (col >> m) & 1 else 0x00)
            pc.card_out(0x3C5, 0x0F)
            ent = 0x1B
        elif mode == 0x13:
            pc.int10(0x0013)
            for y in range(200):
                for x in range(320):
                    pc.card_write(0xA0000 + y * 320 + x, (x + 3 * y) & 0xFF)
            ent = 0x1C
        if ent is not None:
            e = B.entry(rom, ent)
            ht = e['crtc'][0] + 5
            vt = (e['crtc'][6] | ((e['crtc'][7] & 1) << 8) | (((e['crtc'][7] >> 5) & 1) << 9)) + 2
            w = 8 if e['seq'][0] & 1 else 9
            div = 2 if e['seq'][0] & 8 else 1
            pc.lines.append('T %d' % int(2.3 * ht * w * div * vt))
        else:
            pc.lines.append('T 2000')
        pc.lines.append('DUMPR')
        pc.lines.append('DUMPDAC')
        with open(os.path.join(out, name + '.txt'), 'w') as f:
            f.write('# Unicorn execution of the adapter BIOS: %s\n' % name)
            f.write('# POST %r\n' % post)
            f.write('\n'.join(pc.lines) + '\n')
        names.append(name)
        print('%s: %d bus lines, POST beeps %s, 40:87h=%02x 40:88h=%02x 40:89h=%02x 40:10h=%04x '
              'mode 40:49h=%02x, system interrupts %s, system ports %s' % (
                  name, len(pc.lines), post['beeps'], post['487'], post['488'], post['489'],
                  post['410'], post['449'], ['%02x' % i for i in post['ints']],
                  ['%x' % p for p in post['foreign']]))
    with open(os.path.join(out, 'exec_list.txt'), 'w') as f:
        f.write('\n'.join(names) + '\n')


# ------------------------------------------------------------------ check
def dac_from_script(path):
    """DAC contents and PEL mask from the recorded 3C6/3C8/3C9 writes (the
    G171 protocol of p.2-105: address, then R, G, B; auto-increment)."""
    dac = [(0, 0, 0)] * 256
    a, sub, hold, mask = 0, 0, [0, 0], 0
    for ln in open(path):
        t = ln.split()
        if not t or t[0] != 'OW':
            continue
        p, v = int(t[1], 16), int(t[2], 16)
        if p == 0x3C6:
            mask = v
        elif p in (0x3C7, 0x3C8):
            a, sub = v, 0
        elif p == 0x3C9:
            if sub < 2:
                hold[sub] = v & 0x3F
                sub += 1
            else:
                dac[a] = (hold[0], hold[1], v & 0x3F)
                a, sub = (a + 1) & 0xFF, 0
    return dac, mask


def font_glyphs(rom):
    g = {c: list(rom[B.FONT_8X16 + 16 * c: B.FONT_8X16 + 16 * c + 16]) for c in range(256)}
    p = B.PATCH_9X16
    patched = []
    while rom[p]:
        c = rom[p]
        g[c] = list(rom[p + 1: p + 17])
        patched.append(c)
        p += 17
    return g, patched


def expected_image(rom, name, dac, mask):
    if name == 'exec_post_color':
        e = B.entry(rom, 0x18)
        g, _ = font_glyphs(rom)
        pal, am = e['attr'][:16], e['attr'][0x10]
        cells = text_cells()
        img = []
        for row in range(25):
            for sl in range(16):
                line = []
                for col in range(80):
                    ch, at = cells.get((row, col), (0x20, 0x07))
                    bits = g[ch][sl]
                    fg, bg = at & 15, ((at >> 4) & 7) if am & 8 else at >> 4
                    for j in range(9):
                        if j < 8:
                            on = (bits >> (7 - j)) & 1
                        else:                                   # p.2-93
                            on = bits & 1 if (am & 4 and 0xC0 <= ch <= 0xDF) else 0
                        line.append(dac[pal[fg if on else bg] & mask])
                img.append(line)
        return img
    if name == 'exec_mode12':
        e = B.entry(rom, 0x1B)
        pal = e['attr'][:16]
        return [[dac[pal[x // 40] & mask] for x in range(640)] for _ in range(480)]
    if name == 'exec_mode13':
        img = []
        for y in range(200):
            ln = []
            for x in range(320):
                c = dac[((x + 3 * y) & 0xFF) & mask]
                ln += [c, c]                                     # PEL width
            img.append(ln)
            img.append(ln)                                       # MSL 1: two scans
        return img
    return None


def check(rom, base):
    name = os.path.basename(base)
    script = base + '.txt'
    post = eval(open(script).readlines()[1][len('# POST '):])
    fails = []
    if post['beeps']:
        fails.append('POST error beep(s) (DX, caller) = %s' % ['%04x@%04x' % b for b in post['beeps']])
    msg = ('%s: POST without error beeps; 40:87h=%02x 40:88h=%02x 40:89h=%02x equipment %04x '
           'mode %02x' % (name, post['487'], post['488'], post['489'], post['410'], post['449']))
    load = SCEN[name][0]
    # the colour/monochrome decision the BIOS made from the switch sense
    if load == 7 and (post['410'] & 0x30) != 0x20:
        fails.append('colour load: equipment video bits %02x, expected 20h (80x25 colour)' % (post['410'] & 0x30))
    if load == 2 and (post['410'] & 0x30) != 0x30:
        fails.append('mono load: equipment video bits %02x, expected 30h (monochrome)' % (post['410'] & 0x30))
    dac, mask = dac_from_script(script)
    exp = expected_image(rom, name, dac, mask)
    if exp is not None:
        ent = B.entry(rom, {'exec_post_color': 0x18, 'exec_mode12': 0x1B, 'exec_mode13': 0x1C}[name])
        hp, vp = (ent['misc'] >> 6) & 1, (ent['misc'] >> 7) & 1
        fr = B.frames(base + '.rtl', hp, vp)
        f = fr[-2]
        vis = [[((v & 63), (v >> 6) & 63, (v >> 12) & 63) for v in ln if (v >> B.DE) & 1] for ln in f]
        vis = [x for x in vis if x]
        if len(vis) != len(exp) or any(len(a) != len(b) for a, b in zip(vis, exp)):
            fails.append('displayed area %d lines x %s, expected %d x %d'
                         % (len(vis), sorted(set(len(a) for a in vis)), len(exp), len(exp[0])))
        else:
            bad = [(y, x) for y in range(len(exp)) for x in range(len(exp[0])) if vis[y][x] != exp[y][x]]
            if bad:
                y, x = bad[0]
                fails.append('%d pixels differ; first at line %d dot %d: %s vs %s'
                             % (len(bad), y, x, vis[y][x], exp[y][x]))
            else:
                msg += '; %d x %d displayed pixels equal the image rebuilt from the ROM' % (
                    len(exp[0]), len(exp))
        img_dir = os.path.join(os.path.dirname(os.path.dirname(base)), '..', 'img')
        os.makedirs(img_dir, exist_ok=True)
        ppm = os.path.join(img_dir, name + '.ppm')
        with open(ppm, 'wb') as f:
            f.write(b'P6 %d %d 63\n' % (len(vis[0]), len(vis)))
            for ln in vis:
                f.write(bytes(c for px in ln for c in px))
        msg += '; image %s' % os.path.normpath(ppm)
    for x in fails:
        print('FAIL: %s: %s' % (name, x))
    if fails:
        sys.exit(1)
    print('PASS: ' + msg)


def main():
    rom = open(sys.argv[2], 'rb').read()
    if sys.argv[1] == 'gen':
        gen(rom, sys.argv[3])
    else:
        check(rom, sys.argv[3])


if __name__ == '__main__':
    main()
