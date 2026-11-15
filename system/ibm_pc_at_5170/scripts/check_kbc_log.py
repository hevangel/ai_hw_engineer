#!/usr/bin/env python3
"""Check the board's 8042 against the independent UPI-42 reference model.

The POST runner logs what happened to the 8042 (U126) while the BIOS ran:
every instruction the RTL 8042 retired, every host write and data-register
read with its position in the 8042's instruction stream, and every byte the
CPU read from ports 60h/64h. This script replays the host accesses into
design/intel_mcs48/intel_8042/scripts/upi42_iss.py (written from Intel's
UPI-41A manual, not from the RTL) running the same firmware image, and
requires:

  - the model to retire the same instruction addresses in the same order;
  - every status and data byte the CPU read to equal the model's value.

Log records, in time order (hex fields):
  I <pc>             an 8042 instruction or interrupt vector retired
  W <n> <a0> <data>  a host write took effect after <n> instruction starts
  X <n>              a host data-register read took effect (clears OBF)
  S <a0> <data>      the CPU read <data>; a0 = 1 is the status register

Timing rule. In the RTL an instruction samples the host flags (IBF, OBF, F1,
the IBF interrupt request) and the test inputs in its first machine cycle,
and a host access takes effect on the trailing edge of its strobe. An
instruction therefore sees a host access only if the access took effect
before the instruction started; <n> counts the starts before it. The model
applies each access after stepping <n> instructions. A CPU read between an
access taking effect and the next 8042 instruction sees the new flags, so
the expected value overlays the accesses not yet applied to the model.

Board wiring assumed (sheet 17): no keyboard attached, so T0 = NOT P26 and
T1 = P27; the port 1 pins all read 1 except P16 when the display switch
selects colour.

usage: check_kbc_log.py KBC_ROM LOG [P1_PINS_HEX]
"""
import sys
from collections import deque
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[3] / 'design' / 'intel_mcs48' / 'intel_8042' / 'scripts'))
from upi42_iss import UPI42   # noqa: E402


def main():
    if len(sys.argv) not in (3, 4):
        raise SystemExit(__doc__)
    rom = Path(sys.argv[1]).read_bytes()
    p1_pins = int(sys.argv[3], 16) if len(sys.argv) == 4 else 0xFF
    m = UPI42(rom)
    m.reset()
    m.p1_ext = p1_pins
    steps = 0
    queue = deque()              # host accesses not yet applied: (n, kind, a0, data)
    counts = {'I': 0, 'W': 0, 'X': 0, 'S': 0}
    replies = []

    def apply_due():
        while queue and queue[0][0] <= steps:
            _, kind, a0, data = queue.popleft()
            if kind == 'W':
                m.host_write(a0, data)
            else:
                m.host_read(0)

    with Path(sys.argv[2]).open() as log:
        for lineno, line in enumerate(log, 1):
            tok = line.split()
            kind = tok[0]
            counts[kind] += 1
            if kind == 'W':
                queue.append((int(tok[1], 16), 'W', int(tok[2], 16), int(tok[3], 16)))
            elif kind == 'X':
                queue.append((int(tok[1], 16), 'X', 0, 0))
            elif kind == 'I':
                apply_due()
                # No keyboard: the lines follow the board's own drivers.
                m.t0 = (~m.p2_out() >> 6) & 1
                m.t1 = (m.p2_out() >> 7) & 1
                rec = m.step()
                steps += 1
                want = int(tok[1], 16)
                if rec.pc != want:
                    raise SystemExit(
                        'FAIL: log line %d: 8042 instruction %d retired at %03X on the RTL, '
                        '%03X on the model' % (lineno, steps, want, rec.pc))
                if rec.illegal:
                    raise SystemExit('FAIL: model executed an undefined opcode at %03X' % rec.pc)
            elif kind == 'S':
                a0, got = int(tok[1], 16), int(tok[2], 16)
                # Flags as the host sees them now: the model's state plus the
                # accesses that have taken effect but that no 8042 instruction
                # has started after.
                ibf, obf, f1 = m.ibf, m.obf, m.f1
                for _, k, wa0, _ in queue:
                    if k == 'W':
                        ibf, f1 = 1, wa0
                    else:
                        obf = 0
                if a0:
                    want = (m.status() & 0xF4) | (f1 << 3) | (ibf << 1) | obf
                else:
                    want = m.dbbout
                    replies.append(got)
                if got != want:
                    raise SystemExit(
                        'FAIL: log line %d: CPU read %s = %02X, model %02X after %d 8042 '
                        'instructions' % (lineno, 'status' if a0 else 'data', got, want, steps))
            else:
                raise SystemExit('FAIL: log line %d: unknown record %r' % (lineno, kind))
    if queue:
        apply_due()
    print('PASS: 8042 on the board matches the reference model: %d instructions, '
          '%d host writes, %d data reads and %d CPU read values (%d status, %d data)' % (
              counts['I'], counts['W'], counts['X'], counts['S'],
              counts['S'] - len(replies), len(replies)))
    print('8042 data replies: ' + ' '.join('%02X' % v for v in replies))


if __name__ == '__main__':
    main()
