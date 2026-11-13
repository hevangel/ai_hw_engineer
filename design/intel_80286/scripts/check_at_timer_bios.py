#!/usr/bin/env python3
"""Compare a CPU+timer trace with Unicorn, replaying captured input bytes.

The timer itself is not independently checked by this replay. The CPU's
observed I/O inputs are supplied to Unicorn and all CPU architectural state
and data transactions are compared at each instruction boundary (see
bios_replay.py). This script adds the AT fixture's POST checkpoints.
"""
import sys

from bios_replay import replay


def main():
    if len(sys.argv) not in (3, 4):
        raise SystemExit('usage: check_at_timer_bios.py ROM TRACE [page|refresh]')
    checkpoint = sys.argv[3] if len(sys.argv) == 4 else 'page'
    if checkpoint not in ('page', 'refresh'):
        raise ValueError('unknown BIOS checkpoint')
    expected_last_pc = 0xf03a2 if checkpoint == 'refresh' else 0xf038a
    seen = set()
    timer_reads = 0
    refresh_values = set()

    def on_step(pc, next_ip, inputs):
        nonlocal timer_reads
        if 0x41 in inputs:
            timer_reads += 1
        if 0x61 in inputs and 'page' in seen:
            refresh_values.add(bool(inputs[0x61] & 0x10))
        if pc == 0xf0258:
            seen.add('timer1')
        if pc == 0xf027b:
            seen.add('timer2')
        if pc == 0xf02c2:
            seen.add('dma1')
        if pc == 0xf02f8 and next_ip == 0x0302:
            seen.add('dma2')
        if pc == 0xf038a:
            seen.add('page')

    steps, last_pc, _ = replay(sys.argv[1], sys.argv[2], on_step)
    if (seen != {'timer1', 'timer2', 'dma1', 'dma2', 'page'} or
            last_pc != expected_last_pc or not timer_reads or
            (checkpoint == 'refresh' and refresh_values != {False, True})):
        raise ValueError('trace ended before the required timer, DMA and page-register checkpoints')
    print(f'PASS: {steps} CPU instruction states and data transactions match Unicorn; '
          f'{timer_reads} captured timer reads replayed through F000:{expected_last_pc & 0xffff:04X}')


if __name__ == '__main__':
    main()
