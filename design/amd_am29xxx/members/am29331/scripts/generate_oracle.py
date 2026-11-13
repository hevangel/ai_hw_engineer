#!/usr/bin/env python3
"""External AMD Table 1/2 interpreter; no RTL parsing or imported DUT logic."""
import csv, itertools, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
rows = list(csv.reader(line for line in (ROOT / 'references/instructions.csv').read_text().splitlines() if not line.startswith('#') and not line.startswith('op,')))

Y_SRC = ['INC', 'D', 'A', 'MW', 'TOS']
ST_ACT = ['HOLD', 'PUSH_INC', 'PUSH_D', 'PUSH_C', 'POP', 'POP_PUSH_INC', 'SWAP', 'SP_RESET']
CT_ACT = ['HOLD', 'LD_D', 'LD_A', 'DEC', 'LD_TOS', 'SWAP']
CP_ACT = ['HOLD', 'SET', 'CLEAR']
MOD = 33
MASK = (1 << 16) - 1

def row_for(op, c_eq_1, passed):
    """Pick the CSV row. The c1 qualifier follows the datasheet labels:
    '1' rows describe counter != 1, '0' rows counter == 1, 'X' either."""
    def find(passed_):
        cond = 'P' if passed_ else 'F'
        return next(row for row in rows
                    if int(row[0], 16) == op and row[2] == cond
                    and (row[3] == 'X' or (row[3] == '1') != c_eq_1))
    try:
        return find(passed)
    except StopIteration:
        # Unconditional classes (10, 11) never take a fail path: I5 forces
        # the condition true, so the pass row is the only defined behavior.
        return find(True)

def packed(op, c1, passed):
    row = row_for(op, c1, passed)
    return ((Y_SRC.index(row[4]) << 9) | (ST_ACT.index(row[5]) << 6) |
            (CT_ACT.index(row[6]) << 3) | (CP_ACT.index(row[7]) << 1) |
            (row[8] == 'TOS'))

def table_text():
    s = '// Generated exclusively from references/instructions.csv (AMD Tables 1/2).\n'
    s += 'function automatic [11:0] manufacturer_table(input [5:0] op, input c1, input passed);\n  case ({op, c1, passed})\n'
    for op, c1, p in itertools.product(range(64), range(2), range(2)):
        s += f"    8'h{op * 4 + c1 * 2 + p:02x}: manufacturer_table = 12'h{packed(op, bool(c1), bool(p)):03x};\n"
    return s + "    default: manufacturer_table = 12'h000;\n  endcase\nendfunction\n"

if len(sys.argv) > 1 and sys.argv[1] == '--write-table':
    (ROOT / 'formal/table_oracle.svh').write_text(table_text())
    sys.exit(0)
if len(sys.argv) > 1 and sys.argv[1] == '--check-table':
    assert (ROOT / 'formal/table_oracle.svh').read_text() == table_text(), 'formal table differs from manufacturer CSV'
    print('Manufacturer table transcription/generation check PASSED')
    sys.exit(0)

def mod33(v):
    return v - MOD if v >= MOD else v

def condition(s, t):
    if s <= 11:
        return (t >> s) & 1
    if s == 12:
        return ((t >> 8) & 1) | ((t >> 11) & 1)
    if s == 13:
        return (1 - ((t >> 8) & 1)) | ((t >> 11) & 1)
    if s == 14:
        return ((t >> 9) & 1) ^ ((t >> 10) & 1)
    return (((t >> 9) & 1) ^ ((t >> 10) & 1)) | ((t >> 11) & 1)

def cycle(op, pins, s, t, a, d, y_in, m, ar, sp, defined, c, r, cmpen):
    """One microcycle. defined maps physical slot -> known word value.

    Pin byte: bit0 fc, bit1 cin_n, bit2 oed, bit3 inten, bit4 intr,
    bit5 slave, bit6 hold, bit7 rst_n. Returns outputs, next state, the
    defined post-edge stack words (top first) and check-validity flags.
    """
    rst = 1 - ((pins >> 7) & 1)
    fc = pins & 1
    cin_n = (pins >> 1) & 1
    oed = (pins >> 2) & 1
    inten = (pins >> 3) & 1
    intr = (pins >> 4) & 1
    hold = (pins >> 6) & 1
    eff = 0x30 if (rst or fc) else op
    passed = 1 if (eff >> 4) == 0b11 else ((condition(s, t) | ((eff >> 5) & 1)) ^ ((eff >> 4) & 1))
    row = row_for(eff, c == 1, bool(passed))
    y_src, st, ct, cp, dmux = row[4], row[5], row[6], row[7], row[8]
    inc = ar if cin_n else (ar + 1) & MASK
    mw = (d & 0xFFF0) | (m[d & 3] & 0xF)
    tos_idx = mod33((sp - 1) & 63)
    tos = defined.get(tos_idx, 0)
    src = {'INC': inc, 'D': d, 'A': a, 'MW': mw, 'TOS': tos}[y_src]
    y_mux = 0 if rst else src
    intr_acc = bool(intr and inten and not rst and not hold)
    y_oe = int(not hold and not intr_acc)
    d_oe = int(oed and not rst and not hold)
    d_out = tos if dmux == 'TOS' else sp
    inta = 0 if intr_acc else 1
    afull = 1 if sp >= 28 else 0
    int_mux = 0 if rst else (y_in if intr_acc else y_mux)
    equal = 1 if (cmpen and not rst and int_mux == r) else 0
    # Error compares: the driver echoes expected INTA/A-FULL/EQUAL and
    # drives the vector's y_in/d, so only Y and D can disagree.
    err = (1 if (y_oe and y_mux != y_in) else 0) | (1 if (d_oe and d_out != d) else 0)

    # Stack transaction. The accept-cycle instruction completes normally
    # ("interrupted at the completion of the current microcycle"); the
    # interrupt return address is pushed one cycle later, onto the resulting
    # pointer (Figure 5). A stack operation in that following cycle would
    # collide with the automatic push - the datasheet calls it undefined;
    # the RTL resolves it by letting the hardware push win.
    writes = {}
    if st in ('PUSH_INC', 'PUSH_D', 'PUSH_C'):
        writes[mod33(sp)] = {'PUSH_INC': inc, 'PUSH_D': d, 'PUSH_C': c}[st]
        sp_instr = (sp + 1) & 63
    elif st == 'POP':
        sp_instr = (sp - 1) & 63
    elif st == 'POP_PUSH_INC':
        writes[tos_idx] = inc               # pop then push INC, net one write
        sp_instr = sp
    elif st == 'SWAP':
        writes[tos_idx] = c
        sp_instr = sp
    elif st == 'SP_RESET':
        sp_instr = 0
    else:
        sp_instr = sp
    if intr_acc:
        writes[mod33(sp_instr)] = y_mux     # IRAR latched at the accept edge
        sp_next = (sp_instr + 1) & 63
    else:
        sp_next = sp_instr
    c_next = {'LD_D': d, 'LD_A': a, 'DEC': (c - 1) & MASK,
              'LD_TOS': tos, 'SWAP': tos}.get(ct, c)
    r_next = d if cp == 'SET' else r
    cmpen_next = 1 if cp == 'SET' else (0 if cp == 'CLEAR' else cmpen)
    ar_next = y_in if intr_acc else y_mux
    irar_next = y_mux
    if rst:
        # Reset selects address 0, initializes SP and disables comparison;
        # the counter and comparison register contents are retained.
        writes = {}
        ar_next = 0
        sp_next = 0
        cmpen_next = 0
    elif hold:
        # Hold mode leaves the internal state unchanged.
        writes = {}
        ar_next = ar
        sp_next = sp
        c_next = c
        r_next = r
        cmpen_next = cmpen
    equal_next = 1 if (cmpen_next and ar_next == r_next) else 0

    # Undefined-value masks. TOS reads on an empty stack and beyond the
    # first documented overflow wrap are datasheet-undefined; stack reads
    # also require the pre-edge stack to stay inside the documented
    # 33-entry envelope (deep overflow is a modeled choice, not contract).
    tos_read = (y_src == 'TOS') or (dmux == 'TOS') or ct in ('LD_TOS', 'SWAP') or st == 'POP_PUSH_INC'
    values_ok = not tos_read and sp <= 34
    stack_ok = values_ok and sp <= 32 and sp_next <= 33 and sp_next > 0

    new_defined = dict(defined)
    new_defined.update({k: v for k, v in writes.items()})
    read_words = []
    if stack_ok:
        for k in range(min(sp_next, 8)):
            slot = mod33((sp_next - 1 - k) & 63)
            if slot not in new_defined:
                break
            read_words.append(new_defined[slot])
    return {'y': y_mux, 'y_oe': y_oe, 'd': d_out, 'd_oe': d_oe,
            'inta': inta, 'afull': afull, 'equal': equal, 'err': err,
            'ar': ar_next, 'sp': sp_next, 'c': c_next, 'r': r_next,
            'cmpen': cmpen_next, 'equal_next': equal_next, 'accept': intr_acc,
            'valid': (1 if values_ok else 0) | (2 if stack_ok else 0),
            'words': read_words}

class _Rng:
    """Deterministic xorshift32 stimulus: reproducible without the random
    module (same practice as the LFSR stimulus in the SV benches)."""
    def __init__(self, seed):
        self.s = (seed & 0xFFFFFFFF) or 0x29331185

    def randrange(self, n):
        s = self.s
        s ^= (s << 13) & 0xFFFFFFFF
        s ^= s >> 17
        s ^= (s << 5) & 0xFFFFFFFF
        self.s = s
        return s % n

rng = _Rng(0x29331185)
count = 0
lines = []

def init_word(i, words):
    """Driver-pushed stack fill: six explicit words, then a fixed pattern."""
    return words[i] if i < 6 else 0x6600 + i

def emit(op, pins, s, t, a, d, y_in, m, ar, sp, depth, words, c, r, cmpen):
    global count
    count += 1
    defined = {mod33(i): init_word(i, words) for i in range(depth)}
    res = cycle(op, pins, s, t, a, d, y_in, m, ar, sp, defined, c, r, cmpen)
    tail = res['words'] + [0] * (8 - len(res['words']))
    lines.append(' '.join(format(v, 'x') for v in [
        op, pins, s, t, a, d, y_in, *m, ar, sp, depth, *words, c, r, cmpen,
        res['valid'], len(res['words']), res['y'], res['y_oe'], res['d'],
        res['d_oe'], res['inta'], res['afull'], res['equal'], res['err'],
        res['ar'], res['sp'], res['c'], res['equal_next'], *tail]))

def rand_case():
    ar = rng.randrange(1 << 16)
    sp = rng.randrange(64)
    depth = sp  # the driver establishes SP by pushing exactly sp words
    words = [rng.randrange(1 << 16) for _ in range(6)]
    return ar, sp, depth, words

mw_sets = [0x2, 0x4, 0x6, 0x8]
# Systematic sweep: every opcode across condition, carry-in, force-continue,
# output-enable, counter boundary, stack depth band, interrupt request and
# enable. Slave mode is exercised separately in the driver.
for op, t0, cin_n, fc, oed, c, sp, (intr, inten) in itertools.product(
        range(64), (0, 1), (0, 1), (0, 1), (0, 1), (1, 2),
        (0, 1, 5, 27, 28, 33), ((0, 0), (1, 1), (1, 0), (0, 1))):
    pins = fc | (cin_n << 1) | (oed << 2) | (inten << 3) | (intr << 4) | (1 << 7)
    words = [rng.randrange(1 << 16) for _ in range(6)]
    emit(op, pins, 0, t0, rng.randrange(1 << 16), rng.randrange(1 << 16),
         rng.randrange(1 << 16), mw_sets, rng.randrange(1 << 16), sp, sp,
         words, c, rng.randrange(1 << 16), rng.randrange(2))
# Reset (with and without hold) across representative pointers.
for op, hold, sp in itertools.product((0x20, 0x30, 0x34, 0x39, 0x3E), (0, 1), (0, 5, 33, 63)):
    emit(op, (1 << 6) * hold, 0, 0, 0x1234, 0x5678, 0x9abc, mw_sets, 0x04d2,
         sp, sp, [0x1111 * (i + 1) for i in range(6)], 7, 0x04d2, 1)
# Random exploration of the full input and state space.
for _ in range(32768):
    op = rng.randrange(64)
    pins = rng.randrange(256) & ~0x20
    ar, sp, depth, words = rand_case()
    emit(op, pins,
         rng.randrange(16), rng.randrange(1 << 12),
         rng.randrange(1 << 16), rng.randrange(1 << 16), rng.randrange(1 << 16),
         [rng.randrange(16) for _ in range(4)], ar, sp, depth, words,
         rng.randrange(1 << 16), rng.randrange(1 << 16), rng.randrange(2))

# Generated vectors always live in the design's own work tree.
out_path = (ROOT / 'work' / 'sim' / 'vectors.txt').resolve()
out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(''.join(line + '\n' for line in lines))
print(f'Manufacturer Tables 1/2 oracle: {count} independent transitions')
