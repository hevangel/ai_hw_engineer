#!/usr/bin/env python3
"""Compare a CPU+timer trace with Unicorn, replaying captured input bytes.

The timer itself is not independently checked by this replay. The CPU's
observed I/O inputs are supplied to Unicorn and all CPU architectural state
and data transactions are compared at each instruction boundary.
"""
import hashlib
import sys
from pathlib import Path

from generate_firmware_trace import decode
from generate_vectors import Generator, REGS, SEGS, UC_X86_REG_CS, UC_X86_REG_IP, UC_X86_REG_EFLAGS

ROM_SHA256 = '74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f'


def main():
    if len(sys.argv) not in (3, 4):
        raise SystemExit('usage: check_at_timer_bios.py ROM TRACE [page|refresh]')
    checkpoint = sys.argv[3] if len(sys.argv) == 4 else 'page'
    if checkpoint not in ('page', 'refresh'):
        raise ValueError('unknown BIOS checkpoint')
    expected_last_pc = 0xf03a2 if checkpoint == 'refresh' else 0xf038a
    rom = Path(sys.argv[1]).read_bytes()
    if len(rom) != 65536 or hashlib.sha256(rom).hexdigest() != ROM_SHA256:
        raise ValueError('unrecognized IBM AT BIOS')
    g = Generator(None)
    g.uc.mem_write(0xf0000, rom)
    g.shadow.update((0xf0000+i, v) for i, v in enumerate(rom))
    for register in REGS + SEGS:
        g.uc.reg_write(register, 0)
    g.uc.reg_write(UC_X86_REG_CS, 0xf000)
    g.uc.reg_write(UC_X86_REG_EFLAGS, 2)
    ip = 0xe05b
    valid_flags = 0x8fd5
    pending = []
    steps = 0
    timer_reads = 0
    last_pc = None
    first_checkpoint = False
    second_timer_checkpoint = False
    dma1_checkpoint = False
    dma2_checkpoint = False
    page_checkpoint = False
    refresh_values = set()
    with Path(sys.argv[2]).open() as trace:
        for line in trace:
            fields = line.split()
            if not fields:
                raise ValueError('blank trace record')
            if fields[0] == 'B':
                if len(fields) != 5:
                    raise ValueError('malformed bus record')
                pending.append(tuple(int(value, 16) for value in fields[1:]))
                continue
            if fields[0] != 'R' or len(fields) != 15:
                raise ValueError('malformed retirement record')
            values = [int(value, 16) for value in fields[1:]]
            pc, op, next_cs, next_ip, actual_flags, actual_segs, *actual_regs = values
            steps += 1
            if steps == 1:
                if (pc, op, next_cs, next_ip, actual_flags, actual_segs, actual_regs, pending) != (
                        0xfffff0, 0xea, 0xf000, 0xe05b, 2, 0xf0000000, [0]*8, []):
                    raise ValueError('reset-vector transition mismatch')
                last_pc = pc
                continue
            cs = g.uc.reg_read(UC_X86_REG_CS)
            expected_pc = cs*16 + ip
            if pc != expected_pc:
                raise ValueError(f'PC mismatch at step {steps}: CPU {pc:06x}, oracle {expected_pc:06x}')
            decoded = decode(g.uc, pc)
            if decoded is None or decoded[0] != op:
                raise ValueError(f'opcode mismatch at {pc:06x}, CPU {op:02x}, oracle {decoded}')
            _, raw = decoded
            # This firmware uses one byte input per instruction. Reject a
            # trace that would require different values for one port in the
            # same instruction, rather than silently collapsing its history.
            inputs = {}
            for address, value, write, io in pending:
                if io and not write:
                    if address in inputs and inputs[address] != value:
                        raise ValueError('multiple distinct inputs for one port in an instruction')
                    inputs[address] = value
                    if address == 0x41:
                        timer_reads += 1
                    if address == 0x61 and page_checkpoint:
                        refresh_values.add(bool(value & 0x10))
            g.ports.update(inputs)
            before = [g.uc.reg_read(r) for r in REGS]
            g.bus.clear()
            g.seen.clear()
            g.uc.emu_start(pc, 0, count=1)
            if len(g.seen) != 1 or g.seen[0][0] != pc:
                raise ValueError(f'oracle synchronization error at {pc:06x}')
            ip = g.uc.reg_read(UC_X86_REG_IP)
            if op <= 0x3d and op % 8 <= 5 or op in (0x80, 0x81, 0x83):
                kind = (raw[1] >> 3) & 7 if op in (0x80, 0x81, 0x83) else op // 8
                valid_flags |= 0x8d5
                if kind in (1, 4, 6):
                    valid_flags &= ~0x10
            if op in (0x84, 0x85, 0xa8, 0xa9):
                valid_flags = (valid_flags | 0x8c5) & ~0x10
            if op in (0xc0, 0xc1, 0xd0, 0xd1, 0xd2, 0xd3):
                extension = (raw[1] >> 3) & 7
                shift_count = (bytes(g.uc.mem_read(pc, g.seen[0][1]))[-1] & 31) if op in (0xc0, 0xc1) else before[1] & 31 if op in (0xd2, 0xd3) else 1
                if shift_count:
                    if extension >= 4:
                        valid_flags = (valid_flags | 0xc5) & ~0x10
                    valid_flags = valid_flags | 0x800 if shift_count == 1 else valid_flags & ~0x800
                    if extension in (4, 5) and shift_count >= (16 if op & 1 else 8):
                        valid_flags &= ~1
            if op == 0x9e:
                valid_flags |= 0xd5
            flags = g.uc.reg_read(UC_X86_REG_EFLAGS) & 0xffff
            segs = sum(g.uc.reg_read(r) << (16*n) for n, r in enumerate(SEGS))
            regs = [g.uc.reg_read(r) for r in REGS]
            ax_mask = 0xd5ff if op == 0x9f else 0xffff
            if (g.uc.reg_read(UC_X86_REG_CS), ip) != (next_cs, next_ip):
                raise ValueError(f'next CS:IP mismatch at {pc:06x}')
            if (flags ^ actual_flags) & valid_flags or segs != actual_segs:
                raise ValueError(f'flags/segments mismatch at {pc:06x}: CPU {actual_flags:04x}, oracle {flags:04x}, mask {valid_flags:04x}')
            for index, (expected, actual) in enumerate(zip(regs, actual_regs)):
                if (expected ^ actual) & (ax_mask if index == 0 else 0xffff):
                    raise ValueError(f'register {index} mismatch at {pc:06x}: CPU {actual:04x}, oracle {expected:04x}')
            if g.bus != pending:
                raise ValueError(f'bus mismatch at {pc:06x}: CPU {pending}, oracle {g.bus}')
            pending.clear()
            if pc == 0xf0258:
                first_checkpoint = True
            if pc == 0xf027b:
                second_timer_checkpoint = True
            if pc == 0xf02c2:
                dma1_checkpoint = True
            if pc == 0xf02f8 and next_ip == 0x0302:
                dma2_checkpoint = True
            if pc == 0xf038a:
                page_checkpoint = True
            last_pc = pc
    if (pending or not first_checkpoint or not second_timer_checkpoint or
            not dma1_checkpoint or not dma2_checkpoint or not page_checkpoint or
            last_pc != expected_last_pc or not timer_reads or
            (checkpoint == 'refresh' and refresh_values != {False, True})):
        raise ValueError('trace ended before the required timer, DMA and page-register checkpoints')
    print(f'PASS: {steps} CPU instruction states and data transactions match Unicorn; '
          f'{timer_reads} captured timer reads replayed through F000:{expected_last_pc & 0xffff:04X}')


if __name__ == '__main__':
    main()
