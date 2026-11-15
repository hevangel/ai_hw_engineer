#!/usr/bin/env python3
"""Run the reference model on a ROM and stimulus script and write a trace in
the format of tb/lockstep_tb.cpp, or compare against an RTL trace.

usage: upi42_trace.py ROM SCRIPT OUT              write the model trace
       upi42_trace.py ROM SCRIPT OUT --compare RTL compare, report first diff
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from upi42_iss import UPI42   # noqa: E402

TMODE = {'stop': 0, 'timer': 1, 'counter': 2}


def parse_script(path):
    limit, autoread, kbdloop, cmds = 0, False, False, []
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        tok = line.split()
        if tok[0] == 'run':
            limit = int(tok[1])
        elif tok[0] == 'autoread':
            autoread = True
        elif tok[0] == 'kbdloop':
            kbdloop = True
        else:
            cmds.append((int(tok[0]), tok[1], [int(x, 16) for x in tok[2:]]))
    return limit, autoread, kbdloop, cmds


def misc(m):
    return ((m.prescale & 31) << 10) | (TMODE[m.tmode] << 8) | (m.tf << 7) | \
        (m.tie << 6) | (m.tirq << 5) | (m.ie << 4) | (m.ibf_irq << 3) | \
        (m.in_irq << 2) | (m.flags_en << 1) | m.dma_en


def trace(rom, script):
    limit, autoread, kbdloop, cmds = parse_script(script)
    t0_ext = t1_ext = 1
    m = UPI42(rom)
    m.reset()
    lines = []
    ci = 0
    for idx in range(limit):
        while ci < len(cmds) and cmds[ci][0] <= idx:
            if cmds[ci][1] == 'write' and m.ibf:
                break                     # wait for IBF=0, like the BIOS
            _, op, v = cmds[ci]
            ci += 1
            if op in ('write', 'fwrite'):
                m.host_write(v[0], v[1])
            elif op == 'read':
                lines.append('H %d a%d d%02X' % (idx, v[0], m.host_read(v[0])))
            elif op == 'pins':
                m.p1_ext, m.p2_ext, t0_ext, t1_ext = v[0], v[1], v[2] & 1, v[3] & 1
        if kbdloop:
            m.t0 = t0_ext & (~m.p2_out() >> 6) & 1
            m.t1 = t1_ext & (m.p2_out() >> 7) & 1
        else:
            m.t0, m.t1 = t0_ext, t1_ext
        if autoread and m.obf:
            lines.append('H %d a0 d%02X' % (idx, m.host_read(0)))
        r = m.step()
        kind = {'insn': 0, 'irq3': 1, 'irq7': 2}[r.kind]
        op = r.opcode if r.opcode >= 0 else 0
        lines.append(
            'R %d k%d pc%03X op%02X c%d npc%03X a%02X psw%02X sts%02X t%02X '
            'dbi%02X dbo%02X p1%02X p2%02X m%04X ill%d ram%s' % (
                idx, kind, r.pc, op, r.cycles, m.pc, m.a, m.psw(), m.status(),
                m.t, m.dbbin, m.dbbout, m.p1, m.p2_out(), misc(m),
                1 if r.illegal else 0, ''.join('%02X' % b for b in m.ram)))
    return lines


FIELDS = ('kind', 'pc', 'op', 'cycles', 'npc', 'a', 'psw', 'sts', 't', 'dbbin',
          'dbbout', 'p1', 'p2', 'misc', 'illegal', 'ram')


def explain(a, b):
    ta, tb = a.split(), b.split()
    if ta[0] != tb[0] or len(ta) != len(tb):
        return 'record type differs'
    if ta[0] == 'H':
        return 'host read data differs'
    diffs = []
    for name, x, y in zip(FIELDS, ta[2:], tb[2:]):
        if x != y:
            if name == 'ram':
                xs, ys = x[3:], y[3:]
                addrs = [i for i in range(128) if xs[2*i:2*i+2] != ys[2*i:2*i+2]]
                diffs.append('ram at %s' % ', '.join(
                    '%02X model=%s rtl=%s' % (i, xs[2*i:2*i+2], ys[2*i:2*i+2])
                    for i in addrs[:6]))
            else:
                diffs.append('%s model=%s rtl=%s' % (name, x, y))
    return '; '.join(diffs)


def main():
    rom = Path(sys.argv[1]).read_bytes()
    lines = trace(rom, sys.argv[2])
    Path(sys.argv[3]).write_text('\n'.join(lines) + '\n')
    if len(sys.argv) > 5 and sys.argv[4] == '--compare':
        rtl = Path(sys.argv[5]).read_text().splitlines()
        for i, (a, b) in enumerate(zip(lines, rtl)):
            if a != b:
                print('FAIL: first difference at trace line %d' % (i + 1))
                print('  model: ' + a[:120])
                print('  rtl:   ' + b[:120])
                print('  ' + explain(a, b))
                return 1
        if len(lines) != len(rtl):
            print('FAIL: trace lengths differ (model %d, rtl %d)' % (len(lines), len(rtl)))
            return 1
        retires = sum(1 for x in lines if x.startswith('R'))
        reads = len(lines) - retires
        print('PASS: %d retires and %d host reads identical' % (retires, reads))
    return 0


if __name__ == '__main__':
    sys.exit(main())
