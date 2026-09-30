#!/usr/bin/env python3
"""Generate a real-software regression from SCELBAL and the SIMH 8008 model.

The instruction semantics below follow references/simh_i8008.c (SIMH), not
the RTL. The input is the SCELBAL binary referenced by SIMH's SCELBI guide.
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
out = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "build"
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
print(f"Generated 200000 SCELBAL instruction vectors; final PC={pc:04x}; "
      f"HL={regs[5]:02x}{regs[6]:02x}; inputs={io_inputs}, outputs={io_outputs}")
