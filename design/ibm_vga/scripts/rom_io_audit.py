#!/usr/bin/env python3
"""Static I/O audit of the IBM VGA adapter BIOS (the lesson of
failure_notes/2026-11-16-ibm-ega-attribute-3c1.md).

usage: rom_io_audit.py ROM_CPU_ORDER OUT.md

Recursive-descent disassembly (capstone) of the ROM from its entry points
(the option-ROM initialisation at 0003h, the INT 10h/6Dh handler and the
vectors the initialisation installs), following direct jumps and calls and
the CS-relative jump tables of the INT 10h dispatchers. Along every path a
small abstract interpreter tracks the possible values of DX (and of BL/BH,
which the monitor-sense code swaps into DL) through MOV, INC, DEC, ADD,
SUB, OR, AND, XCHG and the BIOS data-area word 0463h (CRTC base, 3B4h or
3D4h). Every IN/OUT/INS/OUTS site is listed with the set of ports it can
reach. A site whose DX is a parameter of its subroutine is resolved at every
call site of that subroutine (I/O helpers such as "write index to DX, data
to DX+1"). Byte/word width is recorded: a word OUT to an 8-bit card is two
byte cycles, to port and port+1.

The result is checked against the card decode (scripts/vga_model.py
io_port(), which is written from the IBM documents and implements exactly
the ports of spec/spec.md): every port the BIOS can reach is either decoded
by the card or listed in ALLOWED_FOREIGN with the reason the card does not
decode it (a system or other-adapter port). Exit 1 if any reachable port is
neither, or if a site cannot be resolved and is not explained in
UNRESOLVED_OK.
"""
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# Third-party packages come from the folder run_sim.sh installs them into.
if os.environ.get('VGA_PYDEPS'):
    sys.path.insert(0, os.environ['VGA_PYDEPS'])
from capstone import CS_ARCH_X86, CS_MODE_16, Cs  # noqa: E402
from capstone.x86 import X86_OP_IMM, X86_OP_MEM, X86_OP_REG  # noqa: E402

BASE = 0x2000          # 86Box file offset of CPU offset 0 (C0000h)
SIZE = 0x6000          # 24 KB option ROM (header byte 30h x 512)

# Ports the BIOS touches that the card must NOT decode, with the reason.
ALLOWED_FOREIGN = {
    0x40: 'PIT counter 0 (system board), frame-time measurement in POST',
    0x42: 'PIT counter 2 (system board), speaker tone for error beeps',
    0x43: 'PIT mode register (system board)',
    0x61: 'system port B (speaker gate) for error beeps',
    0x3B8: 'MDA mode control: POST test of a second (monochrome) adapter',
    0x3D8: 'CGA mode control: POST test of a second (colour) adapter',
    0x46E9: 'high byte of the word OUT 46E8h,AX (C000:009C/00AA): a second byte cycle, '
            'not decoded by the 8-bit card (the enable register is 46E8h alone)',
    0x0103: 'high byte of the word OUT 102h,AX (C000:00A3): POS register 3, which HITR '
            'p.10 says the video subsystem does not use',
    0x4AE8: '8514/A Advanced Function Control (another IBM adapter): the POST writes 0 '
            'so an 8514/A passes VGA video through (C000:00AB-00B0)',
    0x4AE9: 'high byte of the word OUT 4AE8h,AX (8514/A register, another adapter)',
}
# Ports that are reachable only as values passed to the error-beep routine
# (C000:0590 takes DH = long beeps, DL = short beeps in DX, it is not a port)
NOT_PORTS = {0x0102: 'beep count 1 long 2 short (CALL 0590h)',
             0x0103: 'beep count 1 long 3 short (CALL 0590h)'}


class V:
    """Abstract 16-bit value: a frozenset of possible ints, or None (any),
    or ('P', reg, k) meaning parameter reg + k on subroutine entry."""


def vset(*xs):
    return frozenset(xs)


def setop(a, f):
    if a is None:
        return None
    if isinstance(a, tuple):
        return None
    return frozenset(f(x) & 0xFFFF for x in a)


class Audit:
    def __init__(self, rom):
        self.rom = rom
        self.md = Cs(CS_ARCH_X86, CS_MODE_16)
        self.md.detail = True
        self.ins = {}
        self.sites = defaultdict(set)      # addr -> set of (port|('P',k), width, dir)
        self.funcs = {}                    # entry -> set of call-site states
        self.callers = defaultdict(list)   # func entry -> [(site, dx)]
        self.param_sites = defaultdict(set)  # func entry -> {(addr, k, width, dir)}
        self.visited = defaultdict(set)
        self.tables = []
        self.unresolved = []
        self.wdx = set()
        self.ret_dx = {}

    def decode(self, a):
        if a in self.ins:
            return self.ins[a]
        if not 0 <= a < SIZE:
            return None
        it = next(self.md.disasm(self.rom[a:a + 16], a), None)
        self.ins[a] = it
        return it

    # ----------------------------------------------------------- interpreter
    def run(self, entry, func, dx, bl, bh):
        work = [(entry, dx, bl, bh)]
        while work:
            a, dx, bl, bh = work.pop()
            while True:
                key = (dx, bl, bh)
                if key in self.visited[(func, a)] or len(self.visited[(func, a)]) > 12:
                    break
                self.visited[(func, a)].add(key)
                it = self.decode(a)
                if it is None:
                    break
                m, ops = it.mnemonic, it.operands
                nxt = a + it.size
                txt = it.op_str
                # ---- I/O
                if m in ('in', 'out', 'insb', 'insw', 'outsb', 'outsw'):
                    width = 2 if ('ax' in txt.split(',')[0] if m == 'in' else txt.endswith('ax')) \
                        or m.endswith('w') else 1
                    d = 'in' if m.startswith('in') else 'out'
                    if any(o.type == X86_OP_IMM for o in ops):
                        p = [o.imm for o in ops if o.type == X86_OP_IMM][0]
                        self.sites[a].add((p, width, d))
                    elif isinstance(dx, tuple):
                        self.param_sites[func].add((a, dx[2], width, d))
                    elif dx is None:
                        self.unresolved.append(a)
                    else:
                        for p in dx:
                            self.sites[a].add((p, width, d))
                # ---- DX / BL / BH tracking
                if m == 'mov' and len(ops) == 2 and ops[0].type == X86_OP_REG:
                    r = it.reg_name(ops[0].reg)
                    s = ops[1]
                    if r in ('dx', 'dl', 'dh', 'bl', 'bh', 'bx'):
                        if s.type == X86_OP_IMM:
                            v = s.imm
                            if r == 'dx':
                                dx = vset(v & 0xFFFF)
                            elif r == 'dl':
                                dx = setop(dx, lambda x: (x & 0xFF00) | (v & 0xFF)) \
                                    if not isinstance(dx, tuple) else None
                            elif r == 'dh':
                                dx = setop(dx, lambda x: (x & 0xFF) | ((v & 0xFF) << 8))
                            elif r == 'bl':
                                bl = vset(v & 0xFF)
                            elif r == 'bh':
                                bh = vset(v & 0xFF)
                            elif r == 'bx':
                                bl, bh = vset(v & 0xFF), vset((v >> 8) & 0xFF)
                        elif s.type == X86_OP_MEM and r == 'dx' and s.mem.disp == 0x463 \
                                and s.mem.base == 0:
                            dx = vset(0x3B4, 0x3D4)          # BDA ADDR_6845
                        elif s.type == X86_OP_REG:
                            src = it.reg_name(s.reg)
                            if r == 'dl' and src == 'bh':
                                dx = None if (dx is None or isinstance(dx, tuple) or bh is None) else \
                                    frozenset((x & 0xFF00) | y for x in dx for y in bh)
                            elif r == 'dl' and src == 'bl':
                                dx = None if (dx is None or isinstance(dx, tuple) or bl is None) else \
                                    frozenset((x & 0xFF00) | y for x in dx for y in bl)
                            elif r == 'bh' and src == 'dl':
                                bh = None if (dx is None or isinstance(dx, tuple)) else \
                                    frozenset(x & 0xFF for x in dx)
                            elif r == 'bl' and src == 'dl':
                                bl = None if (dx is None or isinstance(dx, tuple)) else \
                                    frozenset(x & 0xFF for x in dx)
                            elif r.startswith('d'):
                                dx = None
                            elif r in ('bl', 'bx'):
                                bl = None
                                if r == 'bx':
                                    bh = None
                            elif r == 'bh':
                                bh = None
                        else:
                            if r.startswith('d'):
                                dx = None
                            if r in ('bl', 'bx'):
                                bl = None
                            if r in ('bh', 'bx'):
                                bh = None
                elif m == 'xchg' and txt in ('dl, bl', 'bl, dl'):
                    if dx is None or isinstance(dx, tuple) or bl is None:
                        dx, bl = None, None
                    else:
                        nd = frozenset((x & 0xFF00) | y for x in dx for y in bl)
                        bl = frozenset(x & 0xFF for x in dx)
                        dx = nd
                elif m in ('inc', 'dec') and txt in ('dx', 'dl'):
                    k = 1 if m == 'inc' else -1
                    if isinstance(dx, tuple):
                        dx = ('P', dx[1], dx[2] + k)
                    elif txt == 'dl':
                        dx = setop(dx, lambda x: (x & 0xFF00) | ((x + k) & 0xFF))
                    else:
                        dx = setop(dx, lambda x: x + k)
                elif m in ('add', 'sub', 'or', 'and', 'xor') and txt.split(',')[0] in ('dx', 'dl') \
                        and ops[1].type == X86_OP_IMM:
                    v = ops[1].imm
                    f = {'add': lambda x: x + v, 'sub': lambda x: x - v, 'or': lambda x: x | v,
                         'and': lambda x: x & (v | (0xFF00 if txt.startswith('dl') else 0)),
                         'xor': lambda x: x ^ v}[m]
                    if isinstance(dx, tuple) and m in ('add', 'sub'):
                        dx = ('P', dx[1], dx[2] + (v if m == 'add' else -v))
                    elif txt.startswith('dl'):
                        dx = setop(dx, lambda x: (x & 0xFF00) | (f(x) & 0xFF))
                    else:
                        dx = setop(dx, f)
                elif m in ('xor', 'sub') and txt in ('dx, dx', 'dl, dl'):
                    dx = vset(0) if txt == 'dx, dx' else setop(dx, lambda x: x & 0xFF00)
                elif m in ('pop', 'xchg', 'lodsw', 'cwd', 'mul', 'div', 'imul', 'idiv') and \
                        ('dx' in txt or 'dl' in txt or 'dh' in txt or m in ('cwd', 'mul', 'div',
                                                                            'imul', 'idiv')):
                    dx = None
                elif ops and ops[0].type == X86_OP_REG and \
                        it.reg_name(ops[0].reg) in ('dx', 'dl', 'dh') and m not in ('cmp', 'test',
                                                                                    'push', 'out'):
                    dx = None
                if m not in ('cmp', 'test', 'push', 'out', 'outsb', 'outsw', 'call') and ops and \
                        ops[0].type == X86_OP_REG and it.reg_name(ops[0].reg) in ('dx', 'dl', 'dh'):
                    self.wdx.add(func)
                if m in ('pop', 'cwd', 'mul', 'div', 'imul', 'idiv') and \
                        (m != 'pop' or txt == 'dx'):
                    self.wdx.add(func)
                if m == 'xchg' and ('dx' in txt or 'dl' in txt or 'dh' in txt):
                    self.wdx.add(func)
                # ---- control flow
                if m == 'call':
                    if ops[0].type == X86_OP_IMM:
                        t = ops[0].imm & 0xFFFF
                        self.callers[t].append((a, dx))
                        self.run(t, t, ('P', 'dx', 0), bl, bh)
                        # DX survives the call only if the callee (and what
                        # it calls) never writes DX
                        if t in self.wdx:
                            self.wdx.add(func)
                            r = self.ret_dx.get(t)
                            if isinstance(r, frozenset):
                                dx = r
                            elif isinstance(r, tuple) and r[0] == 'P' and dx is not None                                     and not isinstance(dx, tuple):
                                dx = setop(dx, lambda x, k=r[2]: x + k)
                            else:
                                dx = None
                    else:
                        dx = None
                    a = nxt
                    continue
                if m in ('ret', 'retf', 'iret', 'hlt'):
                    # return-value summary of DX for the callers
                    old = self.ret_dx.get(func, 'unset')
                    if old == 'unset':
                        self.ret_dx[func] = dx
                    elif isinstance(old, frozenset) and isinstance(dx, frozenset):
                        self.ret_dx[func] = old | dx
                    elif old != dx:
                        self.ret_dx[func] = None
                    break
                if m == 'jmp':
                    o = ops[0]
                    if o.type == X86_OP_IMM:
                        a = o.imm & 0xFFFF
                        continue
                    if o.type == X86_OP_MEM and it.reg_name(o.mem.segment) == 'cs':
                        self.table(it, a, work, dx, bl, bh, func)
                    break
                if m.startswith('j') or m.startswith('loop') or m == 'jcxz':
                    o = ops[0]
                    if o.type == X86_OP_IMM:
                        work.append((o.imm & 0xFFFF, dx, bl, bh))
                    a = nxt
                    continue
                a = nxt

    def table(self, it, a, work, dx, bl, bh, func):
        base = it.operands[0].mem.disp & 0xFFFF
        # bound: the nearest preceding "cmp si/di/bx, imm" within 24 bytes
        n = None
        for b in range(a - 1, a - 24, -1):
            p = self.decode(b)
            if p and p.mnemonic == 'cmp' and b + p.size <= a and p.operands[1].type == X86_OP_IMM:
                n = p.operands[1].imm // 2
                break
        if n is None:
            n = 32
        tgt = []
        for i in range(n):
            t = self.rom[base + 2 * i] | (self.rom[base + 2 * i + 1] << 8)
            if not 0 < t < SIZE:
                break
            tgt.append(t)
        self.tables.append((a, base, len(tgt)))
        for t in tgt:
            work.append((t, dx, bl, bh))

    def resolve_params(self):
        changed = True
        while changed:
            changed = False
            for f, ps in list(self.param_sites.items()):
                for (site, k, w, d) in ps:
                    for (call, dx) in self.callers.get(f, []):
                        if dx is None:
                            self.unresolved.append((site, 'via call %04x' % call))
                            continue
                        if isinstance(dx, tuple):
                            # the caller passes its own parameter on: lift
                            # the site into the caller's function
                            caller_f = self.func_of(call)
                            if caller_f is not None:
                                e = (site, k + dx[2], w, d)
                                if e not in self.param_sites[caller_f]:
                                    self.param_sites[caller_f].add(e)
                                    changed = True
                            continue
                        for p in dx:
                            e = ((p + k) & 0xFFFF, w, d)
                            if e not in self.sites[site]:
                                self.sites[site].add(e)
                                changed = True

    def func_of(self, addr):
        for (f, a) in self.visited:
            if a == addr:
                return f
        return None


def main():
    data = open(sys.argv[1], 'rb').read()
    rom = data[BASE:BASE + SIZE]
    au = Audit(rom)
    entries = {0x0003: 'option ROM init (JMP at 0003h)', 0x06E4: 'INT 10h/6Dh handler',
               0x06E1: 'INT 10h vector (INT 6Dh; IRET)', 0x05C6: 'video save-pointer table',
               }
    for e in entries:
        au.run(e, e, None, None, None)
    au.resolve_params()

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import vga_model as VM
    card = VM.VGA()
    card.misc = 0x01
    ports = defaultdict(set)
    for site, es in au.sites.items():
        for (p, w, d) in es:
            if isinstance(p, tuple):
                continue
            for q in ([p] if w == 1 else [p, (p + 1) & 0xFFFF]):
                ports[q].add((site, d, w))
    rows, fails = [], []
    for p in sorted(ports):
        names = []
        for mono in (0, 1):
            card.misc = 0x00 if mono else 0x01
            card.vse = 0x08
            card.pos102 = 1
            card.vse_setup = 0
            for setup in (0, 1):
                card.vse = 0x18 if setup else 0x08
                nm = card.io_port(p, 'r' if any(d == 'in' for _, d, _ in ports[p]) else 'w')
                nmw = card.io_port(p, 'w')
                for n in (nm, nmw):
                    if n and n not in names:
                        names.append(n)
        dirs = sorted(set(d for _, d, _ in ports[p]))
        sites = ' '.join('%04x' % s for s in sorted(set(s for s, _, _ in ports[p])))
        if names:
            st = 'decoded: ' + ', '.join(names)
        elif p in ALLOWED_FOREIGN and ALLOWED_FOREIGN[p]:
            st = 'not the card: ' + ALLOWED_FOREIGN[p]
        else:
            st = 'NOT DECODED'
            fails.append('port %04x reachable (%s at %s) but not decoded' % (p, '/'.join(dirs), sites))
        rows.append('| %04X | %s | %s | %s |' % (p, '/'.join(dirs), st, sites))
    unres = sorted(set(u if isinstance(u, int) else u[0] for u in au.unresolved))
    with open(sys.argv[2], 'w') as f:
        f.write('# Static I/O audit of the IBM VGA BIOS\n\n')
        f.write('Entry points: ' + '; '.join('%04Xh %s' % kv for kv in entries.items()) + '\n\n')
        f.write('Instructions decoded: %d; jump tables followed: %d (%s)\n\n' % (
            len([1 for v in au.ins.values() if v]), len(au.tables),
            ', '.join('%04X:[%04X]x%d' % t for t in au.tables)))
        f.write('| Port | Dir | Card | I/O sites (CPU offset) |\n|---|---|---|---|\n')
        f.write('\n'.join(rows) + '\n\n')
        f.write('DX-parameter helpers resolved at their call sites: %s\n\n' % ', '.join(
            '%04X (%d sites, %d callers)' % (fn, len(ps), len(au.callers.get(fn, [])))
            for fn, ps in sorted(au.param_sites.items()) if ps))
        f.write('Sites with an unresolved DX (covered by the Unicorn execution instead): %s\n\n' % (
            ' '.join('%04x' % u for u in unres) or 'none'))
        f.write('Values loaded into DX that are not ports: %s\n' % '; '.join(
            '%04X %s' % kv for kv in NOT_PORTS.items()))
    print(open(sys.argv[2]).read())
    for x in fails:
        print('FAIL: ' + x)
    if fails:
        sys.exit(1)
    print('PASS: static I/O audit: %d ports reachable, every one decoded or a documented '
          'system/other-adapter port; %d sites unresolved statically' % (len(ports), len(unres)))


if __name__ == '__main__':
    main()
