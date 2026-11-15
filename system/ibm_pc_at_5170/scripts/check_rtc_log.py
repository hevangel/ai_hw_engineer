#!/usr/bin/env python3
"""Check the board's MC146818 against the independent reference model.

The POST runner logs what happened to the MC146818 (U117) while the BIOS
ran: every address strobe, data write and data read with the number of
oscillator periods the chip had counted when it took effect, and every byte
the CPU read from port 71h. This script replays the log into
design/motorola_mc146818/scripts/mc146818_model.py (written from the Motorola
data sheet, not from the RTL), starting from the same power-on image, and
requires every byte the CPU read to equal the model's value.

Log records, in time order (hex fields; <t> = oscillator periods counted):
  A <t> <byte>   address strobe took effect with this bus value
  W <t> <byte>   data write took effect
  V <t> <byte>   value the CPU read from port 71h
  R <t>          that read took effect (register C clears on read)

The CPU samples a read value at the end of its bus cycle and the chip applies
the read's side effect one or two clocks later, so the value (V) is compared
with the model's side-effect-free view and the side effect is applied at R.

usage: check_rtc_log.py NVRAM_IMAGE LOG
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[3] / 'design' / 'motorola_mc146818' / 'scripts'))
from mc146818_model import MC146818, load_image   # noqa: E402


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    m = MC146818(load_image(sys.argv[1]))
    ticks = 0
    counts = {'A': 0, 'W': 0, 'V': 0, 'R': 0}
    read_addrs = {}
    with Path(sys.argv[2]).open() as log:
        for lineno, line in enumerate(log, 1):
            tok = line.split()
            kind, t = tok[0], int(tok[1], 16)
            if kind not in counts:
                raise SystemExit('FAIL: log line %d: unknown record %r' % (lineno, kind))
            counts[kind] += 1
            if t < ticks:
                raise SystemExit('FAIL: log line %d: oscillator count went backwards' % lineno)
            while ticks < t:
                m.tick()
                ticks += 1
            if kind == 'A':
                m.addr_strobe(int(tok[2], 16))
            elif kind == 'W':
                m.write(int(tok[2], 16))
            elif kind == 'V':
                got, want = int(tok[2], 16), m.view(m.addr)
                read_addrs[m.addr] = read_addrs.get(m.addr, 0) + 1
                if got != want:
                    raise SystemExit(
                        'FAIL: log line %d: CPU read location %02X = %02X, model %02X after %d '
                        'oscillator periods' % (lineno, m.addr, got, want, ticks))
            else:
                m.read()
    print('PASS: MC146818 on the board matches the reference model: %d address strobes, '
          '%d writes and %d CPU read values over %d oscillator periods (%.1f s of clock time)'
          % (counts['A'], counts['W'], counts['V'], ticks, ticks / 32768.0))
    print('locations read: ' + ' '.join('%02X:%d' % kv for kv in sorted(read_addrs.items())))
    print('time at the end: %02X:%02X:%02X' % (m.view(4), m.view(2), m.view(0)))


if __name__ == '__main__':
    main()
