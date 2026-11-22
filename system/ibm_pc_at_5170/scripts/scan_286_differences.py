#!/usr/bin/env python3
"""Count the instructions of an AT trace whose result differs between the
8086/8088 and the 80286, by code region.

usage: scan_286_differences.py TRACE

The trace is the processor trace of host/simulator.cpp --trace or
tb/post_runner.cpp (R records: physical PC, opcode, CS, IP, flags, segments,
AX CX DX BX SP BP SI DI after the instruction). Counted, from the Intel
80286 data sheet and programmer's reference (210498-005, appendix "80286
and 8086 differences" and the instruction set) against the 8086 family
user's manual:

  push-sp        PUSH SP (54h): the 286 pushes SP as it was before the
                 push, the 8086 the decremented value
  shift-cl>31    shift/rotate by CL (D2h/D3h) with CL >= 32: the 286 masks
                 the count to 5 bits, the 8086 uses all 8
  new-opcode     opcodes the 8086 decodes differently (C0h/C1h, C8h/C9h,
                 60h-62h, 68h-6Fh, 0Fh, D6h, F1h): 186/286 instructions or
                 #UD on the 286; on the 8086 aliases or undefined
  a20 changes    G records (the 8042's A20 gate output changed)
  wrapped fetch  instructions at 100000h-10FFEFh, which the 8086 reaches
                 by wrapping at 1 MB and the AT only with A20 gated off
                 (PC DOS 1.00's CALL 5 entry, F01D:FEF0 = 1000C0h)

and the trace's exception and reset records are counted by the Unicorn
replay (check_post_trace.py) separately.
Regions: system BIOS (F0000h-F5FFFh, FE000h-FFFFFh and the FF0000h image),
ROM BASIC (F6000h-FDFFFh), VGA BIOS (C0000h-C7FFFh), RAM (DOS and programs).
"""
import sys
from collections import Counter

NEW = {0xc0, 0xc1, 0xc8, 0xc9, 0x60, 0x61, 0x62, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f,
       0x0f, 0xd6, 0xf1}


def region(pc):
    if 0x100000 <= pc < 0x10fff0:
        return 'above 1 MB (wrapped)'
    if pc >= 0xff0000 or 0xf0000 <= pc < 0xf6000 or 0xfe000 <= pc < 0x100000:
        return 'system BIOS'
    if 0xf6000 <= pc < 0xfe000:
        return 'ROM BASIC'
    if 0xc0000 <= pc < 0xc8000:
        return 'VGA BIOS'
    return 'RAM'


def main():
    counts = Counter()
    retired = Counter()
    gates = 0
    cl = 0
    with open(sys.argv[1]) as f:
        for line in f:
            if line[0] == 'G':
                gates += 1
                continue
            if line[0] != 'R':
                continue
            fields = line.split()
            pc, op = int(fields[1], 16), int(fields[2], 16)
            r = region(pc)
            retired[r] += 1
            if r == 'above 1 MB (wrapped)':
                counts[('wrapped fetch %02X' % op, r)] += 1
            if op == 0x54:
                counts[('push-sp', r)] += 1
            elif op in (0xd2, 0xd3) and cl >= 32:
                counts[('shift-cl>31', r)] += 1
            elif op in NEW:
                counts[('new-opcode %02X' % op, r)] += 1
            cl = int(fields[8], 16) & 0xff   # CL after this instruction
    print('retired by region: ' + ', '.join(f'{k} {v}' for k, v in sorted(retired.items())))
    if not counts:
        print('no PUSH SP, shift by CL >= 32 or 8086-undefined opcode retired')
    for (kind, r), n in sorted(counts.items()):
        print(f'{kind}: {n} in {r}')
    print(f'A20 gate changes: {gates}')


if __name__ == '__main__':
    main()
