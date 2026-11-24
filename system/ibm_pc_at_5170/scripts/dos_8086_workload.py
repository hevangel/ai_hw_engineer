#!/usr/bin/env python3
"""Run the IBM PC (8088) diskette DOS workload on a machine, through its
public simulator line protocol and its real keyboard path only.

The same keystrokes and the same screen conditions drive three machines:

  at   the IBM PC AT 5170 VGA machine (host/simulator.cpp; 80286, unchanged
       AT REV1 BIOS, 1.2 MB drive A, 360 KB drive B; keys enter the AT
       keyboard model as scan code set 2 and pass through the 8042)
  pc   the IBM PC 5150 (system/ibm_pc; 8088, keys as set 1 scan codes)
  xt   the IBM PC XT 5160 (system/ibm_pc_xt_5160; 8088, booted from drive A)

Workloads:

  dos100  the steps of system/ibm_pc/scripts/test_software.py on PC DOS 1.00
          (160 KB): date entry, DIR, CHKDSK, FORMAT B: (accept, then decline
          another), COPY TIME.COM B:CLOCK.COM, DIR B:, BASIC with PRINT 6*7
          and SYSTEM, BASICA DONKEY with two space-bar presses (pc, at)
  dos200  the diskette steps of system/ibm_pc_xt_5160/scripts/test_software.py
          on PC DOS 2.00 (180 KB): date and time, DIR, ECHO into a file on B:,
          TYPE it, COPY CON into a file on B:, TYPE it, BASIC with PRINT 6*7
          and SYSTEM (xt, at)

The result (OUT/result.json) holds every step's final screen and the screens
seen while waiting, the machine counters and the drive B image saved after
the run (OUT/drive_b.img); scripts/compare_8086.py compares two results.
Nothing in the run intercepts the CPU, BIOS or DOS: the machine only gets
key events and run slices.

usage:
  dos_8086_workload.py at  WORKLOAD OUT SIM BIOS VGA_ROM DRIVE_A DRIVE_B [--trace=PATH --trace-clocks=N]
  dos_8086_workload.py pc  dos100   OUT SIM REFERENCE_DIR
  dos_8086_workload.py xt  dos200   OUT SIM REFERENCE_DIR HARD_DISK
"""
import base64
import json
import os
import re
import shutil
import subprocess
import sys
import time
import zlib
from pathlib import Path

# Set 1 make codes (IBM PC/XT keyboard, Technical Reference "Keyboard Scan
# Codes"), US layout; shifted characters map to their unshifted key.
SET1 = {**dict(zip('qwertyuiop', range(16, 26))), **dict(zip('asdfghjkl', range(30, 39))),
        **dict(zip('zxcvbnm', range(44, 51))), **dict(zip('1234567890', range(2, 12))),
        ' ': 57, '\r': 28, '-': 12, '=': 13, ',': 51, '.': 52, '/': 53, ';': 39, "'": 40,
        '[': 26, ']': 27, '\\': 43, '`': 41}
SHIFTED = {':': ';', '"': "'", '*': '8', '(': '9', ')': '0', '+': '=', '?': '/', '!': '1',
           '>': '.', '<': ',', '_': '-', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7'}
CTRL_Z = ('ctrl', 'z')


class Machine:
    """Common wait loop; subclasses implement the protocol."""
    hz = 1.0
    slice = 1000000
    name = '?'

    def __init__(self, log):
        self.log = log
        self.trail = []

    def wait(self, predicate, seconds, label):
        """Run until predicate(self, text, history) holds, at most `seconds`
        of machine time; returns (text, distinct screens seen)."""
        stop = self.clocks() + int(seconds * self.hz)
        seen = []
        t0 = time.time()
        while True:
            text = self.screen()
            if not seen or seen[-1] != text:
                seen.append(text)
            if predicate(self, text, '\n'.join(seen)):
                print(f'PASS[{self.name}]: {label} at {self.clocks()} clocks, '
                      f'{self.instructions()} instructions ({time.time() - t0:.0f} s wall)', flush=True)
                return text, seen
            if 'bad-disk unusable' in text.lower():
                raise AssertionError(f'{label}: DOS reported a bad disk\n{text}')
            if self.clocks() >= stop:
                raise AssertionError(f'[{self.name}] {label}: timeout at {self.where()} after '
                                     f'{seconds} s machine time\n{text}')
            self.run(self.slice)


class AtMachine(Machine):
    hz = 6e6          # processor clocks per second on the AT time base (AT20)
    slice = 2000000
    name = 'at'

    def __init__(self, sim, bios, vga, drive_a, drive_b, log, extra=()):
        super().__init__(log)
        args = [sim, bios, vga, f'--fda={drive_a}', '--fda-type=1.2', '--fda-ro', f'--fdb={drive_b}',
                '--fdb-type=360', '--fst=' + str(Path(log.name).with_suffix('.fst')), *extra]
        self.p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=log,
                                  text=True, bufsize=1)
        self.state = self.cmd('STATE')

    def cmd(self, line):
        self.p.stdin.write(line + '\n')
        self.p.stdin.flush()
        raw = self.p.stdout.readline()
        if not raw:
            raise RuntimeError('AT simulator exited; see ' + self.log.name)
        reply = json.loads(raw)
        if 'error' in reply:
            raise RuntimeError(f'AT simulator: {reply["error"]} ({line})')
        if 'clocks' in reply:
            self.state = reply
            if reply['stopped']:
                raise AssertionError('AT machine stopped: ' + reply['stopped'])
        return reply

    def clocks(self):
        return self.state['clocks']

    def instructions(self):
        return self.state['instructions']

    def where(self):
        return f'{self.state["cs"]}:{self.state["ip"]} post {self.state["post"]}'

    def run(self, n):
        self.cmd(f'RUN {n}')

    def idle(self):
        k = self.state['keyboard']
        return (k['pendingKeys'] == 0 and k['queued'] == 0 and
                self.state['kbdHead'] == self.state['kbdTail'])

    def screen(self):
        """The screen read from the last video frame with the VGA ROM's font
        (CODES), written as Pc8088Machine.screen writes video memory:
        codes 20h-7Eh as themselves, every other code as a space. A cell
        that matches no glyph is '?'. Columns beyond the mode's width (40 in
        BASIC's WIDTH 40) read as blank."""
        codes = self.cmd('CODES')['codes']
        rows = [''.join(chr(c) if 32 <= c < 127 else '?' if c < 0 else ' ' for c in row)
                for row in codes]
        rows = [r.rstrip() for r in rows] + [''] * (25 - len(rows))
        # The cursor cell reads as '?' in its blink-on phase; the BIOS's
        # cursor position for page 0 (0:0450 column, 0:0451 row) says which.
        pos = bytes.fromhex(self.cmd('PEEK 450 2')['hex'])
        col, row = pos[0], pos[1]
        if row < 25 and col < len(rows[row]) and rows[row][col] == '?':
            rows[row] = (rows[row][:col] + ' ' + rows[row][col + 1:]).rstrip()
        return '\n'.join(rows)

    def type(self, items):
        for item in items:
            if item == CTRL_Z:
                self.cmd('TYPE Ctrl+z')
            else:
                esc = item.replace('\\', '\\\\').replace('"', '\\"').replace('\r', '\\n')
                self.cmd(f'TYPE "{esc}"')

    def media_reads(self):
        return self.state['diskette']['mediaReads']

    def media_writes(self):
        return self.state['diskette']['mediaWrites']

    def graphics(self):
        return self.state['biosMode'] in (4, 5, 6)

    def picture(self):
        """(hash of the frame, number of distinct colours in it)."""
        f = self.cmd('FRAME')
        png = base64.b64decode(f['png'])
        width, height = f['width'], f['height']
        pos, idat = 8, b''
        while pos < len(png):
            n = int.from_bytes(png[pos:pos + 4], 'big')
            if png[pos + 4:pos + 8] == b'IDAT':
                idat += png[pos + 8:pos + 8 + n]
            pos += 12 + n
        raw = zlib.decompress(idat)
        stride = width * 3 + 1
        colours = {raw[y * stride + 1 + 3 * x:y * stride + 4 + 3 * x]
                   for y in range(0, height, 2) for x in range(0, width, 2)}
        return hash(raw), len(colours)

    def save_b(self, path):
        self.cmd(f'SAVE 1 {path}')

    def counters(self):
        s = self.state
        return {k: s[k] for k in ('clocks', 'instructions', 'cpuResets', 'interruptAcks', 'dmaWrites',
                                  'dmaReads', 'dmaOpen', 'biosMode', 'traceEnd', 'traceInstructions')} | {
            'diskette': s['diskette']}

    def close(self):
        if self.p.poll() is None:
            self.p.stdin.write('QUIT\n')
            self.p.stdin.flush()
            self.p.wait(timeout=600)


class Pc8088Machine(Machine):
    """system/ibm_pc and system/ibm_pc_xt_5160 share this protocol."""
    hz = 4772727
    slice = 1000000

    def __init__(self, name, sim, reference, log, env=None):
        super().__init__(log)
        self.name = name
        self.p = subprocess.Popen([sim, reference], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=log, text=True, bufsize=1, env=env)
        self.state = self.cmd('STATE')
        self.cmd('RESET')

    def cmd(self, line):
        self.p.stdin.write(line + '\n')
        self.p.stdin.flush()
        raw = self.p.stdout.readline()
        if not raw:
            raise RuntimeError(f'{self.name} simulator exited; see {self.log.name}')
        reply = json.loads(raw)
        if 'cycles' in reply:
            self.state = reply
            if reply.get('fault'):
                raise AssertionError(f'{self.name}: RTL fault at {self.where()}')
        return reply

    def clocks(self):
        return self.state['cycles']

    def instructions(self):
        return self.state['instructions']

    def where(self):
        return f'{self.state["cs"]:04X}:{self.state["ip"]:04X}'

    def run(self, n):
        self.cmd(f'RUN {n}')

    def idle(self):
        return self.state['keysQueued'] == 0

    def screen(self):
        s = self.state
        ram = bytes.fromhex(s['vram'])
        cols = 80 if s['mode'] & 1 else 40
        start = ((s['crtc'][12] << 8) | s['crtc'][13]) * 2
        rows = []
        for row in range(25):
            line = ''.join(chr(c) if 32 <= c < 127 else ' '
                           for c in (ram[(start + 2 * (row * cols + col)) & 16383] for col in range(cols)))
            rows.append(line.rstrip())
        return '\n'.join(rows)

    def key(self, code):
        self.cmd(f'KEY {code}')

    def type(self, items):
        for item in items:
            if item == CTRL_Z:
                for code in (29, SET1['z'], SET1['z'] | 128, 29 | 128):
                    self.key(code)
                continue
            for char in item:
                shifted = char in SHIFTED or char.isupper()
                code = SET1[SHIFTED.get(char, char.lower())]
                if shifted:
                    self.key(42)
                self.key(code)
                self.key(code | 128)
                if shifted:
                    self.key(42 | 128)

    def media_reads(self):
        return self.state['mediaReads']

    def media_writes(self):
        return self.state['mediaWrites']

    def graphics(self):
        return bool(self.state['mode'] & 2)

    def picture(self):
        vram = bytes.fromhex(self.state['vram'])
        return hash(vram), len(set(vram))

    def save_b(self, path):
        self.cmd(f'SAVE 1 {path}')

    def counters(self):
        s = self.state
        return {k: s.get(k) for k in ('cycles', 'instructions', 'mediaReads', 'mediaWrites', 'dma',
                                      'mode', 'postErrors')}

    def close(self):
        if self.p.poll() is None:
            self.p.stdin.write('QUIT\n')
            self.p.stdin.flush()
            self.p.wait(timeout=60)


def prompt(t):
    return t.rstrip().endswith('A>')


def above_function_keys(t):
    """BASIC shows its function-key line in row 25; ignore that row."""
    return t.rsplit('\n', 1)[0].rstrip()


def dos100(m):
    """test_software.py's steps; returns [(label, final screen, screens)]."""
    steps = []

    def step(label, keys, predicate, seconds=60):
        if keys:
            m.type(keys)
        text, seen = m.wait(predicate, seconds, label)
        steps.append({'label': label, 'keys': [k if isinstance(k, str) else '^Z' for k in keys],
                      'screen': text, 'seen': seen, 'clocks': m.clocks(),
                      'graphicsMode': m.graphics()})
        return text, seen

    step('POST and PC DOS 1.00 boot', [], lambda m, t, h: "Enter today's date" in t, 200)
    step('date entry', ['10-14-81\r'],
         lambda m, t, h: m.idle() and 'Version 1.00' in t and prompt(t))
    step('DIR', ['dir\r'],
         lambda m, t, h: m.idle() and re.search(r'COMMAND\s+COM', h) and prompt(t))
    step('CHKDSK', ['chkdsk\r'], lambda m, t, h: m.idle() and 'bytes' in h.lower() and prompt(t))
    step('FORMAT B: prompt', ['format b:\r'],
         lambda m, t, h: 'Insert new diskette for drive B:' in t and 'strike any key when ready' in t)
    step('FORMAT B: 40 tracks', ['\r'],
         lambda m, t, h: m.idle() and 'Format complete' in h and 'Format another (Y/N)?' in t, 120)
    step('FORMAT declines another', ['n'], lambda m, t, h: m.idle() and prompt(t))
    writes = m.media_writes()
    step('COPY TIME.COM B:CLOCK.COM', ['copy time.com b:clock.com\r'],
         lambda m, t, h: m.idle() and m.media_writes() > writes and prompt(t))
    step('DIR B:', ['dir b:\r'],
         lambda m, t, h: m.idle() and re.search(r'CLOCK\s+COM', t) and prompt(t))
    step('BASIC', ['basic\r'], lambda m, t, h: 'Ok' in t and ('Basic' in t or 'BASIC' in t))
    step('PRINT 6*7', ['print 6*7\r'],
         lambda m, t, h: m.idle() and re.search(r'\b42\b', t) and above_function_keys(t).endswith('Ok'))
    step('SYSTEM', ['system\r'], lambda m, t, h: m.idle() and prompt(t))
    reads = m.media_reads()
    step('BASICA DONKEY title', ['basica donkey\r'],
         lambda m, t, h: m.idle() and 'DONKEY' in t and 'Press space bar to continue' in t, 80)
    step('DONKEY graphics', [' '],
         lambda m, t, h: m.idle() and m.graphics() and m.media_reads() > reads and m.picture()[1] >= 3, 80)
    first = m.picture()
    m.type([' '])
    m.wait(lambda m, t, h: m.idle(), 10, 'DONKEY space bar taken')
    m.run(int(0.6 * m.hz))
    second = m.picture()
    assert m.graphics() and second[0] != first[0], 'DONKEY picture did not change after the space bar'
    print(f'PASS[{m.name}]: DONKEY picture changed after the space bar '
          f'({first[1]} and {second[1]} distinct values)', flush=True)
    steps.append({'label': 'DONKEY space bar', 'keys': [' '], 'screen': '', 'seen': [],
                  'clocks': m.clocks(), 'graphics': [first[1], second[1]]})
    return steps


def dos200(m):
    steps = []

    def step(label, keys, predicate, seconds=60):
        if keys:
            m.type(keys)
        text, seen = m.wait(predicate, seconds, label)
        steps.append({'label': label, 'keys': [k if isinstance(k, str) else '^Z' for k in keys],
                      'screen': text, 'seen': seen, 'clocks': m.clocks(),
                      'graphicsMode': m.graphics()})
        return text, seen

    step('POST and PC DOS 2.00 boot', [], lambda m, t, h: 'Enter new date' in t, 200)
    step('date entry', ['10-14-81\r'], lambda m, t, h: 'Enter new time' in t)
    step('time entry', ['\r'], lambda m, t, h: m.idle() and prompt(t))
    text, seen = step('DIR', ['dir\r'],
                      lambda m, t, h: m.idle() and re.search(r'COMMAND\s+COM', h) and prompt(t))
    assert 'bytes free' in '\n'.join(seen).lower()
    writes = m.media_writes()
    step('ECHO into B:ECHO.TXT', ['echo AT 5170 8086 COMPAT>b:echo.txt\r'],
         lambda m, t, h: m.idle() and m.media_writes() > writes and prompt(t))
    step('TYPE B:ECHO.TXT', ['type b:echo.txt\r'],
         lambda m, t, h: m.idle() and re.search(r'^AT 5170 8086 COMPAT$', t, re.M) and prompt(t))
    # Not CON.TXT: DOS 2.00 takes a device name with any extension for the
    # device, so COPY CON CON.TXT copies the keyboard to the screen.
    writes = m.media_writes()
    step('COPY CON B:KEYED.TXT', ['copy con b:keyed.txt\r', 'HELLO FROM COPY CON\r', CTRL_Z, '\r'],
         lambda m, t, h: m.idle() and m.media_writes() > writes and 'File(s) copied' in h and prompt(t))
    step('TYPE B:KEYED.TXT', ['type b:keyed.txt\r'],
         lambda m, t, h: m.idle() and re.search(r'^HELLO FROM COPY CON$', t, re.M) and prompt(t))
    step('BASIC', ['basic\r'], lambda m, t, h: 'Ok' in t and ('Basic' in t or 'BASIC' in t))
    step('PRINT 6*7', ['print 6*7\r'],
         lambda m, t, h: m.idle() and re.search(r'\b42\b', t) and above_function_keys(t).endswith('Ok'))
    step('SYSTEM', ['system\r'], lambda m, t, h: m.idle() and prompt(t))
    return steps


def main():
    if len(sys.argv) < 5:
        raise SystemExit(__doc__)
    kind, workload, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    log = (out / 'simulator.log').open('w')
    t0 = time.time()
    if kind == 'at':
        sim, bios, vga, drive_a, drive_b = sys.argv[4:9]
        extra = sys.argv[9:]
        shutil.copyfile(drive_a, out / 'drive_a.img')
        shutil.copyfile(drive_b, out / 'drive_b_initial.img')
        m = AtMachine(sim, bios, vga, out / 'drive_a.img', out / 'drive_b_initial.img', log, extra)
    elif kind == 'pc':
        sim, reference = sys.argv[4:6]
        m = Pc8088Machine('pc', sim, reference, log)
    elif kind == 'xt':
        sim, reference, hard_disk = sys.argv[4:7]
        shutil.copyfile(hard_disk, out / 'harddisk.img')
        env = {**os.environ, 'IBM_XT_BOOT': 'A', 'IBM_XT_DISK': str(out / 'harddisk.img')}
        m = Pc8088Machine('xt', sim, reference, log, env)
    else:
        raise SystemExit('machine must be at, pc or xt')
    result = {'machine': kind, 'workload': workload}
    try:
        steps = {'dos100': dos100, 'dos200': dos200}[workload](m)
        m.save_b(str(out / 'drive_b.img'))
        result.update(steps=steps, counters=m.counters(), wallSeconds=round(time.time() - t0))
    finally:
        try:
            m.close()
        finally:
            log.close()
    (out / 'result.json').write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS[{kind}]: {workload} workload complete, {result["counters"]}', flush=True)


if __name__ == '__main__':
    main()
