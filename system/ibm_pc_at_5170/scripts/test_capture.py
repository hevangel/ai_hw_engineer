#!/usr/bin/env python3
"""A waveform capture must not change the machine: compare CAPTURE with RUN.

usage: test_capture.py SIMULATOR BIOS_ROM VGA_ROM WORK_DIR

Two simulator processes power on, run the same warm-up, then one captures
N clocks to FST while the other just runs N clocks; their states (CPU,
counters, keyboard, BIOS keyboard data area) must be equal. Repeated for
three window sizes, including a power-on (RESET) before each capture.
"""
import json
from pathlib import Path
import subprocess
import sys

IGNORED = ('captureStart', 'captureClocks', 'captureVersion', 'clocksPerSecond', 'realTimeFraction')


def main():
    sim, bios, vga, work = sys.argv[1:5]
    procs = [subprocess.Popen([sim, bios, vga, f'--fst={Path(work) / name}.fst'], stdin=subprocess.PIPE,
                              stdout=subprocess.PIPE, text=True, bufsize=1) for name in ('captured', 'ordinary')]

    def cmd(i, line):
        procs[i].stdin.write(line + '\n')
        procs[i].stdin.flush()
        reply = json.loads(procs[i].stdout.readline())
        if 'error' in reply:
            raise SystemExit(f'FAIL: {line}: {reply["error"]}')
        return reply
    try:
        for warmup, clocks in ((20000, 1024), (300000, 4096), (2000000, 65536)):
            for i in range(2):
                cmd(i, 'RESET')
                cmd(i, f'RUN {warmup}')
            a = cmd(0, f'CAPTURE {clocks}')
            b = cmd(1, f'RUN {clocks}')
            if a['captureClocks'] != clocks or not Path(work, 'captured.fst').stat().st_size:
                raise SystemExit('FAIL: the capture did not record the window')
            for s in (a, b):
                for k in IGNORED:
                    s.pop(k)
            if a != b:
                raise SystemExit(f'FAIL: capture of {clocks} clocks changed the machine state')
            print(f'capture of {clocks} clocks after {warmup}: state equal ({a["instructions"]} instructions, '
                  f'{Path(work, "captured.fst").stat().st_size} byte FST)')
        print('PASS: waveform captures leave the machine exactly as an ordinary run')
    finally:
        for p in procs:
            if p.poll() is None:
                p.stdin.write('QUIT\n')
                p.stdin.flush()
                p.wait(timeout=30)


if __name__ == '__main__':
    main()
