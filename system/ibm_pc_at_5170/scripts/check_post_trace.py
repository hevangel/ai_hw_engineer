#!/usr/bin/env python3
"""Check an IBM PC AT system POST trace against Unicorn.

Every retired instruction, its register state and its data transfers must
match Unicorn, with the board's observed I/O input bytes replayed (see
design/intel_80286/scripts/bios_replay.py). The run stops inside the
instruction that touched unmodeled hardware, so trailing data records of
that unfinished instruction are allowed.

The last retired instruction must leave the CPU at STOP_CS:IP, the
boundary the runner reported, so Unicorn agrees on where the run stopped.
The BIOS's own POST tests that passed on the way are listed.
"""
import sys

from bios_replay import replay

# (retired PC, next IP or None): reaching the instruction after a BIOS test's
# final branch shows the test passed instead of falling into its error HLT.
CHECKPOINTS = {
    'timer channel 1 bit tests': (0xf0258, None),
    'timer channel 1 second bit test': (0xf027b, None),
    'DMA controller 1 registers': (0xf02c2, None),
    'DMA controller 2 registers': (0xf02f8, 0x0302),
    'page registers': (0xf038a, None),
    'refresh indication': (0xf03a2, None),
}


def main():
    if len(sys.argv) != 4:
        raise SystemExit('usage: check_post_trace.py ROM TRACE STOP_CS:IP')
    stop_cs, stop_ip = (int(part, 16) for part in sys.argv[3].split(':'))
    reached = []
    last_next = None

    def on_step(pc, next_ip, inputs):
        nonlocal last_next
        last_next = next_ip
        for name, (want_pc, want_ip) in CHECKPOINTS.items():
            if pc == want_pc and (want_ip is None or next_ip == want_ip) and name not in reached:
                reached.append(name)

    steps, last_pc, trailing = replay(sys.argv[1], sys.argv[2], on_step, allow_trailing=True)
    # The BIOS stays in segment F000 for all code reached so far, so the
    # stop is checked as F000:IP; a far transfer elsewhere would fail here.
    if stop_cs != 0xf000 or last_next != stop_ip:
        raise ValueError(f'oracle ends at F000:{last_next or 0:04X}, runner reported {sys.argv[3]}')
    print(f'PASS: {steps} instruction states and data transfers match Unicorn up to '
          f'{sys.argv[3]}; {len(trailing)} data transfers in the unfinished instruction')
    print('POST tests passed: ' + (', '.join(reached) if reached else 'none'))


if __name__ == '__main__':
    main()
