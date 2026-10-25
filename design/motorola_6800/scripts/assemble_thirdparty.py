"""Assemble and check the vendored hakanrw/mc6800 third-party test programs.

Each tests/*.asm (MIT-licensed self-checking MC6800 programs from
github.com/hakanrw/mc6800, vendored in references/hakanrw_mc6800/) is
assembled by the small assembler below, loaded into the RTL testbench
(tb_thirdparty.sv) one at a time, and free-run until the program reaches
its end-of-test self-loop. A test passes when it reaches the self-loop
with a clean $2000-$20FF marker window (every generic test signals
failure by writing a nonzero byte into that window; success does
CLR $2000). swi.asm writes its own progress marks into $2000-$2003, so
it carries an explicit expected-window rule.
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DESIGN_ROOT = HERE.parent
REF_DIR = (DESIGN_ROOT / 'references' / 'hakanrw_mc6800').resolve()
OUT_DIR = (DESIGN_ROOT / 'work' / 'third').resolve()
if DESIGN_ROOT not in REF_DIR.parents or DESIGN_ROOT not in OUT_DIR.parents:
    raise RuntimeError('path escapes the design tree')

# opcode tables: mnemonic -> (imm, dir, ext, ind) first bytes / inherent byte
ALU8 = {
    'SUBA': (0x80, 0x90, 0xB0, 0xA0), 'SUBB': (0xC0, 0xD0, 0xF0, 0xE0),
    'CMPA': (0x81, 0x91, 0xB1, 0xA1), 'CMPB': (0xC1, 0xD1, 0xF1, 0xE1),
    'SBCA': (0x82, 0x92, 0xB2, 0xA2), 'SBCB': (0xC2, 0xD2, 0xF2, 0xE2),
    'ANDA': (0x84, 0x94, 0xB4, 0xA4), 'ANDB': (0xC4, 0xD4, 0xF4, 0xE4),
    'BITA': (0x85, 0x95, 0xB5, 0xA5), 'BITB': (0xC5, 0xD5, 0xF5, 0xE5),
    'LDAA': (0x86, 0x96, 0xB6, 0xA6), 'LDAB': (0xC6, 0xD6, 0xF6, 0xE6),
    'STAA': (None, 0x97, 0xB7, 0xA7), 'STAB': (None, 0xD7, 0xF7, 0xE7),
    'EORA': (0x88, 0x98, 0xB8, 0xA8), 'EORB': (0xC8, 0xD8, 0xF8, 0xE8),
    'ADCA': (0x89, 0x99, 0xB9, 0xA9), 'ADCB': (0xC9, 0xD9, 0xF9, 0xE9),
    'ORAA': (0x8A, 0x9A, 0xBA, 0xAA), 'ORAB': (0xCA, 0xDA, 0xFA, 0xEA),
    'ADDA': (0x8B, 0x9B, 0xBB, 0xAB), 'ADDB': (0xCB, 0xDB, 0xFB, 0xEB),
    'CPX': (0x8C, 0x9C, 0xBC, 0xAC),
    'LDS': (0x8E, 0x9E, 0xBE, 0xAE), 'STS': (None, 0x9F, 0xBF, 0xAF),
    'LDX': (0xCE, 0xDE, 0xFE, 0xEE), 'STX': (None, 0xDF, 0xFF, 0xEF),
}
ALU8['STA'] = ALU8['STAA']   # arithmetic.asm uses the STA alias
INHERENT = {
    'NOP': 0x01, 'TAP': 0x06, 'TPA': 0x07, 'INX': 0x08, 'DEX': 0x09,
    'CLV': 0x0A, 'SEV': 0x0B, 'CLC': 0x0C, 'SEC': 0x0D, 'CLI': 0x0E,
    'SEI': 0x0F, 'SBA': 0x10, 'CBA': 0x11, 'TAB': 0x16, 'TBA': 0x17,
    'DAA': 0x19, 'ABA': 0x1B, 'TSX': 0x30, 'INS': 0x31, 'PULA': 0x32,
    'PULB': 0x33, 'DES': 0x34, 'TXS': 0x35, 'PSHA': 0x36, 'PSHB': 0x37,
    'RTS': 0x39, 'RTI': 0x3B, 'WAI': 0x3E, 'SWI': 0x3F,
    'NEGA': 0x40, 'COMA': 0x43, 'LSRA': 0x44, 'RORA': 0x46,
    'ASRA': 0x47, 'ASLA': 0x48, 'ROLA': 0x49, 'DECA': 0x4A,
    'INCA': 0x4C, 'TSTA': 0x4D, 'CLRA': 0x4F,
    'NEGB': 0x50, 'COMB': 0x53, 'LSRB': 0x54, 'RORB': 0x56,
    'ASRB': 0x57, 'ASLB': 0x58, 'ROLB': 0x59, 'DECB': 0x5A,
    'INCB': 0x5C, 'TSTB': 0x5D, 'CLRB': 0x5F,
}
RMW = {'NEG': (None, 0x60, 0x70), 'COM': (None, 0x63, 0x73),
       'LSR': (None, 0x64, 0x74), 'ROR': (None, 0x66, 0x76),
       'ASR': (None, 0x67, 0x77), 'ASL': (None, 0x68, 0x78),
       'ROL': (None, 0x69, 0x79), 'DEC': (None, 0x6A, 0x7A),
       'INC': (None, 0x6C, 0x7C), 'TST': (None, 0x6D, 0x7D),
       'CLR': (None, 0x6F, 0x7F)}
BRANCH = {'BRA': 0x20, 'BHI': 0x22, 'BLS': 0x23, 'BCC': 0x24,
          'BCS': 0x25, 'BNE': 0x26, 'BEQ': 0x27, 'BVC': 0x28,
          'BVS': 0x29, 'BPL': 0x2A, 'BMI': 0x2B, 'BGE': 0x2C,
          'BLT': 0x2D, 'BGT': 0x2E, 'BLE': 0x2F}
JUMPS = {'JMP': ('ind', 'ext'), 'JSR': ('ind', 'ext'), 'BSR': ('rel',)}

# tests with explicit marker-window expectations (address -> byte)
SPECIAL_RULES = {
    'swi': {0x2000: 0x01, 0x2001: 0x01, 0x2002: 0x02, 0x2003: 0x02},
}


class AsmError(Exception):
    pass


def parse_value(tok, labels):
    tok = tok.strip()
    if tok.startswith('#'):
        tok = tok[1:]
    neg = tok.startswith('-')
    if neg:
        tok = tok[1:]
    if tok.startswith('$'):
        v = int(tok[1:], 16)
    elif tok.startswith('%'):
        v = int(tok[1:], 2)
    elif tok.isdigit():
        v = int(tok, 10)
    else:
        v = labels[tok]
    return -v if neg else v


KNOWN = set(ALU8) | set(INHERENT) | set(RMW) | set(BRANCH) | set(JUMPS) \
    | {'ORG', 'FCB', 'FDB'}


def strip_label(text, labels, cur):
    """Handle a leading 'name:' or a lone non-mnemonic symbol (asl-style
    colon-less label). Returns the remaining text."""
    m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*):', text)
    if m:
        labels[m.group(1)] = cur
        return text[m.end():].strip()
    parts = text.split(None, 1)
    if len(parts) == 1 and parts[0].upper() not in KNOWN:
        labels[parts[0]] = cur
        return ''
    return text


def assemble(src, org_default=0x0000):
    labels = {}
    fixups = []          # (index_in_out, kind, token, line_no)
    out = bytearray()
    org = org_default
    cur = org

    def emit(bs):
        nonlocal cur
        out.extend(bs)
        cur += len(bs)

    lines = src.splitlines()
    # pass 1: labels
    cur = org
    pc_of = []
    for ln, raw in enumerate(lines, 1):
        text = raw.split(';', 1)[0].strip()
        if not text:
            continue
        text = strip_label(text, labels, cur)
        if not text:
            continue
        parts = text.split(None, 1)
        mnem = parts[0].upper()
        arg = parts[1].strip() if len(parts) > 1 else ''
        if mnem == 'ORG':
            org = parse_value(arg, labels)
            cur = org
        elif mnem in ('FCB',):
            for v in arg.split(','):
                pc_of.append(cur)
                cur += 1
        elif mnem in ('FDB',):
            for v in arg.split(','):
                pc_of.append(cur)
                cur += 2
        else:
            size = instr_size(mnem, arg)
            pc_of.append(cur)
            cur += size
    # pass 2
    out.clear()
    cur = org
    for ln, raw in enumerate(lines, 1):
        text = raw.split(';', 1)[0].strip()
        if not text:
            continue
        text = strip_label(text, labels, cur)
        if not text:
            continue
        parts = text.split(None, 1)
        mnem = parts[0].upper()
        arg = parts[1].strip() if len(parts) > 1 else ''
        if mnem == 'ORG':
            cur = parse_value(arg, labels)
            pad = cur - len(out)
            if pad < 0:
                raise AsmError(f'line {ln}: ORG backwards')
            out.extend(b'\x00' * pad)
        elif mnem == 'FCB':
            for v in arg.split(','):
                out.append(parse_value(v, labels) & 0xFF)
                cur += 1
        elif mnem == 'FDB':
            for v in arg.split(','):
                val = parse_value(v, labels)
                out += bytes([(val >> 8) & 0xFF, val & 0xFF])
                cur += 2
        else:
            emit_instr(mnem, arg, labels, fixups, out, ln)
            cur = org + len(out)
    for idx, kind, tok, ln in fixups:
        target = labels[tok]
        if kind == 'rel':
            off = target - (org + idx + 2)
            if not -128 <= off <= 127:
                raise AsmError(f'line {ln}: branch out of range')
            out[idx + 1] = off & 0xFF
        else:
            out[idx + 1] = (target >> 8) & 0xFF
            out[idx + 2] = target & 0xFF
    return bytes(out), labels


def instr_size(mnem, arg):
    if mnem in ALU8 or mnem in RMW or mnem in JUMPS:
        if not arg:
            raise AsmError(f'{mnem} needs an operand')
        a = arg.upper().replace(' ', '')
        if a.endswith(',X'):
            return 2
        if a.startswith('#'):
            return 2 if mnem not in ('LDS', 'LDX', 'STX', 'STS', 'CPX') else 3
        if a in ('A', 'B') and mnem in RMW:
            return 1
        v = None
        try:
            v = parse_value(a, {})
        except Exception:
            return 3  # label: worst case (rel may be 2; fixed in pass 2)
        return 2 if v < 0x100 and mnem not in RMW and mnem not in JUMPS \
            else 3
    if mnem in BRANCH:
        return 2
    if mnem in INHERENT:
        return 1
    raise AsmError(f'unknown mnemonic {mnem}')


def emit_instr(mnem, arg, labels, fixups, out, ln):
    base = len(out)
    if mnem in INHERENT:
        if arg and arg.upper() not in ('A', 'B'):
            raise AsmError(f'line {ln}: {mnem} takes no operand')
        out.append(INHERENT[mnem])
        return
    if mnem in BRANCH:
        out.append(BRANCH[mnem])
        out.append(0)
        fixups.append((base, 'rel', arg, ln))
        return
    if mnem in ('LDS', 'LDX', 'STX', 'STS', 'CPX') and arg.startswith('#'):
        out.append(ALU8[mnem][0])
        v = parse_value(arg, labels)
        out += bytes([(v >> 8) & 0xFF, v & 0xFF])
        return
    if mnem in ALU8:
        imm, dr, ex, ind = ALU8[mnem]
        a = arg.upper().replace(' ', '')
        if a.endswith(',X'):
            off = 0 if a[:-2] == '' else parse_value(a[:-2], labels)
            out.append(ind)
            out.append(off & 0xFF)
        elif a.startswith('#'):
            if imm is None:
                raise AsmError(f'line {ln}: {mnem} has no immediate mode')
            out.append(imm)
            out.append(parse_value(arg, labels) & 0xFF)
        elif a in ('A', 'B') and mnem in RMW:
            out.append(INHERENT[mnem + a.capitalize()])
        else:
            v = parse_value(arg, labels)
            if v < 0x100 and dr is not None:
                out.append(dr)
                out.append(v & 0xFF)
            else:
                out.append(ex)
                out += bytes([(v >> 8) & 0xFF, v & 0xFF])
        return
    if mnem in RMW:
        _, ind, ex = RMW[mnem]
        a = arg.upper().replace(' ', '')
        if a.endswith(',X'):
            off = 0 if a[:-2] == '' else parse_value(a[:-2], labels)
            out.append(ind)
            out.append(off & 0xFF)
        elif a in ('A', 'B'):
            out.append(INHERENT[mnem + a.capitalize()])
        else:
            v = parse_value(arg, labels)
            out.append(ex)
            out += bytes([(v >> 8) & 0xFF, v & 0xFF])
        return
    if mnem in JUMPS:
        kinds = JUMPS[mnem]
        a = arg.upper().replace(' ', '')
        if a.endswith(',X') and 'ind' in kinds:
            off = 0 if a[:-2] == '' else parse_value(a[:-2], labels)
            op = 0x6E if mnem == 'JMP' else 0xAD
            out.append(op)
            out.append(off & 0xFF)
        elif kinds == ('rel',):
            out.append(0x8D)
            out.append(0)
            fixups.append((base, 'rel', arg, ln))
        else:
            v = parse_value(arg, labels)
            out.append(0x7E if mnem == 'JMP' else 0xBD)
            out += bytes([(v >> 8) & 0xFF, v & 0xFF])
        return
    raise AsmError(f'line {ln}: unknown mnemonic {mnem}')


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    tests = sorted(REF_DIR.glob('*.asm'))
    if not tests:
        raise SystemExit('no vendored test sources found')
    manifest = []
    for t in tests:
        name = t.stem
        image = bytearray(65536)
        org = 0x1000 if name == 'swi' else 0x0000
        code, labels = assemble(t.read_text(), org_default=org)
        end = org + len(code)
        if name == 'swi':
            # the source's FDB table is relocated to the real vector area
            for vec_addr, lbl in ((0xFFFA, 'SWIH'), (0xFFFC, 'NMIH'),
                                  (0xFFFE, 'START')):
                v = labels[lbl]
                image[vec_addr] = (v >> 8) & 0xFF
                image[vec_addr + 1] = v & 0xFF
            # drop the in-image FDB copy (last 6 bytes before EOF)
            code = code[:-6]
        image[org:org + len(code)] = code
        # terminator: BRA * right after the image (code includes any ORG pad)
        end = len(code)
        image[end] = 0x20
        image[end + 1] = 0xFE
        (OUT_DIR / f'{name}.hex').write_text(
            ''.join(f'{b:02x}\n' for b in image))
        manifest.append(name)
    (OUT_DIR / 'manifest.txt').write_text('\n'.join(manifest) + '\n')
    rules = {n: SPECIAL_RULES.get(n, {}) for n in manifest}
    import json
    (OUT_DIR / 'rules.json').write_text(
        json.dumps({k: {hex(a): v for a, v in r.items()}
                    for k, r in rules.items()}))
    print(f'assembled {len(manifest)} third-party tests into {OUT_DIR}')


if __name__ == '__main__':
    main()
