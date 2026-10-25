#!/usr/bin/env python3
"""Generate a real-software regression from SCELBAL and the SIMH 8008 model.

The instruction semantics below follow references/simh_i8008.c (SIMH), not
the RTL. The input is the SCELBAL binary referenced by SIMH's SCELBI guide.

The run also emits an opcode histogram (build/scelbal_opcount.txt) and a
family coverage summary, so the claim "200,000 authentic instructions" carries
measured opcode coverage with it (review F3, 2026-10-23). With
--strict-coverage the script fails when any defined instruction family is
absent from the trace.
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
strict = "--strict-coverage" in sys.argv
out = Path(sys.argv[1]) if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else root / "build"
out.mkdir(parents=True, exist_ok=True)
mem = [0] * 0x4000
program = (root / "references/scelbal_sc1.bin").read_bytes()
assert len(program) == 11942, "unexpected SCELBAL image size"
mem[0x40:0x40 + len(program)] = program

# SIMH's SCELBI guide uses octal 0100, i.e. hex 0x0040.
mem[:3] = [0x44, 0x40, 0x00]
(out / "scelbal_mem.hex").write_text("".join(f"{v:02x}\n" for v in mem))

regs = [0] * 7
stack = [0] * 8
sp = pc = 0
c = z = s = p = 0
io_inputs = io_outputs = 0
opcount = {}

def szp(v):
    global z, s, p
    v &= 255
    z, s, p = int(v == 0), (v >> 7) & 1, int(v.bit_count() % 2 == 0)

def flag(n):
    return (c, z, s, p)[n]

def alu(kind, value):
    global c
    a = regs[0]
    if kind == 0: result = a + value
    elif kind == 1: result = a + value + c
    elif kind == 2: result = a - value
    elif kind == 3: result = a - value - c
    elif kind == 4: result = a & value
    elif kind == 5: result = a ^ value
    elif kind == 6: result = a | value
    else: result = a - value
    c = int(bool(result & 0x100)) if kind < 4 or kind == 7 else 0
    szp(result)
    if kind != 7:
        regs[0] = result & 255

def byte():
    global pc
    result = mem[pc]
    pc = (pc + 1) & 0x3fff
    return result

def push(addr):
    global sp
    stack[sp] = addr
    sp = (sp + 1) & 7

def pop():
    global sp
    sp = (sp - 1) & 7
    return stack[sp]

def step():
    global pc, c, io_inputs, io_outputs
    op = byte()
    opcount[op] = opcount.get(op, 0) + 1
    hl = ((regs[5] << 8) | regs[6]) & 0x3fff
    if op in (0, 1, 255):
        return False
    if op & 0xc7 == 0xc7:      # LdM
        regs[(op >> 3) & 7] = mem[hl]
    elif op & 0xf8 == 0xf8:    # LMs
        mem[hl] = regs[op & 7]
    elif op & 0xc0 == 0xc0:    # Lds
        regs[(op >> 3) & 7] = regs[op & 7]
    elif op == 0x3e:          # LMI
        mem[hl] = byte()
    elif op & 0xc7 == 0x06:    # LdI
        regs[(op >> 3) & 7] = byte()
    elif op & 0xc7 in (0, 1): # INr / DCr
        i = (op >> 3) & 7
        if i == 7:
            pass  # INr/DCr M is undefined; the RTL spec models it as a NOP.
                  # SIMH instead updates the flags with no register write, a
                  # divergence documented in spec/spec.md.
        else:
            regs[i] = (regs[i] + (1 if op & 1 == 0 else -1)) & 255
            szp(regs[i])
    elif op & 0xc0 == 0x80:   # accumulator with register or memory
        alu((op >> 3) & 7, mem[hl] if op & 7 == 7 else regs[op & 7])
    elif op & 0xc7 == 0x44:   # unconditional JMP aliases
        lo, hi = byte(), byte()
        pc = ((hi << 8) | lo) & 0x3fff
    elif op & 0xe7 in (0x40, 0x60): # conditional jumps
        lo, hi = byte(), byte()
        if flag((op >> 3) & 3) == (op >> 5) & 1:
            pc = ((hi << 8) | lo) & 0x3fff
    elif op & 0xc7 == 0x46:   # unconditional CAL aliases
        lo, hi = byte(), byte()
        push(pc)
        pc = ((hi << 8) | lo) & 0x3fff
    elif op & 0xe7 in (0x42, 0x62): # conditional calls
        lo, hi = byte(), byte()
        if flag((op >> 3) & 3) == (op >> 5) & 1:
            push(pc)
            pc = ((hi << 8) | lo) & 0x3fff
    elif op & 0xc7 == 0x07:   # RET aliases
        pc = pop()
    elif op & 0xe7 in (0x03, 0x23): # conditional returns
        if flag((op >> 3) & 3) == (op >> 5) & 1:
            pc = pop()
    elif op & 0xc7 == 0x05:   # RST
        push(pc)
        pc = op & 0x38
    elif op & 0xc1 == 0x41:   # INP / OUT; all inputs tied low
        if (op >> 1) & 0x1f < 8:
            io_inputs += 1
            regs[0] = 0
        else:
            io_outputs += 1
    elif op & 0xc7 == 0x04:   # ALU immediate
        alu((op >> 3) & 7, byte())
    elif op == 0x02:
        c = regs[0] >> 7
        regs[0] = ((regs[0] << 1) | c) & 255
    elif op == 0x0a:
        c = regs[0] & 1
        regs[0] = (regs[0] >> 1) | (c << 7)
    elif op == 0x12:
        old = c
        c = regs[0] >> 7
        regs[0] = ((regs[0] << 1) | old) & 255
    elif op == 0x1a:
        old = c
        c = regs[0] & 1
        regs[0] = (regs[0] >> 1) | (old << 7)
    return True

with (out / "scelbal_expected.hex").open("w") as trace:
    for n in range(200000):
        if not step():
            raise RuntimeError(f"SCELBAL halted after {n} instructions at {pc:04x}")
        value = pc
        for reg in regs:
            value = (value << 8) | reg
        value = (value << 4) | ((c << 3) | (z << 2) | (s << 1) | p)
        value = (value << 3) | sp
        trace.write(f"{value:020x}\n")
(out / "scelbal_final_mem.hex").write_text("".join(f"{v:02x}\n" for v in mem))

# Opcode family coverage of the executed trace (review F3). Every family the
# spec defines must be visible somewhere in the design's verification; this
# report shows which families authentic SCELBAL execution covers and which are
# left to the directed tests.
FAMILIES = {
    "HLT (000/001/377)": lambda op: op in (0x00, 0x01, 0xFF),
    "Lds move (11dddsss)": lambda op: op & 0xC0 == 0xC0,
    "LdI immediate (00ddd110)": lambda op: op & 0xC7 == 0x06,
    "INr (00ddd000, ddd#7)": lambda op: op & 0xC7 == 0x00 and op not in (0x00, 0x38),
    "DCr (00ddd001, ddd#7)": lambda op: op & 0xC7 == 0x01 and op not in (0x01, 0x39),
    "ALU register (10ooosss, sss#7)": lambda op: op & 0xC0 == 0x80 and op & 7 != 7,
    "ALU memory (10ooo111)": lambda op: op & 0xC0 == 0x80 and op & 7 == 7,
    "ALU immediate (00ooo100)": lambda op: op & 0xC7 == 0x04,
    "Rotates (02/0a/12/1a)": lambda op: op in (0x02, 0x0A, 0x12, 0x1A),
    "JMP unconditional": lambda op: op & 0xC7 == 0x44,
    "JMP conditional": lambda op: op & 0xE7 in (0x40, 0x60),
    "CAL unconditional": lambda op: op & 0xC7 == 0x46,
    "CAL conditional": lambda op: op & 0xE7 in (0x42, 0x62),
    "RET unconditional": lambda op: op & 0xC7 == 0x07,
    "RET conditional false (RFc)": lambda op: op & 0xE7 == 0x03,
    "RET conditional true (RTc)": lambda op: op & 0xE7 == 0x23,
    "RST (00eee101)": lambda op: op & 0xC7 == 0x05,
    "INP (input group)": lambda op: op & 0xC1 == 0x41 and (op >> 1) & 0x1F < 8,
    "OUT (output latch)": lambda op: op & 0xC1 == 0x41 and (op >> 1) & 0x1F >= 8,
}
covered = {}
for op, count in sorted(opcount.items()):
    for name, matches in FAMILIES.items():
        if matches(op):
            covered.setdefault(name, [0, set()])
            covered[name][0] += count
            covered[name][1].add(op)
            break

with (out / "scelbal_opcount.txt").open("w") as hist:
    hist.write("# opcode execution counts over the 200000-instruction SCELBAL trace\n")
    for op, count in sorted(opcount.items()):
        hist.write(f"{op:02x} {count}\n")

absent = [name for name in FAMILIES if name not in covered]
print(f"Generated 200000 SCELBAL instruction vectors; final PC={pc:04x}; "
      f"HL={regs[5]:02x}{regs[6]:02x}; inputs={io_inputs}, outputs={io_outputs}")
print(f"Opcode families executed: {len(covered)}/{len(FAMILIES)}; "
      f"distinct opcodes: {len(opcount)}")
for name in FAMILIES:
    if name in covered:
        count, ops = covered[name]
        print(f"  covered  {name}: {count}x ({len(ops)} opcodes)")
    else:
        print(f"  ABSENT   {name}")
if absent:
    message = "opcode families absent from the SCELBAL trace: " + "; ".join(absent)
    if strict:
        raise SystemExit(message)
    print(f"WARNING ({message}); rerun with --strict-coverage to fail on this")
