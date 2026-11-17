#!/usr/bin/env python3
"""Check an IBM PC AT system POST trace against Unicorn.

Every retired instruction, its register state and its data transfers must
match Unicorn, with the board's observed I/O input bytes replayed (see
design/intel_80286/scripts/bios_replay.py). The run stops inside the
instruction that touched unmodeled hardware, so trailing data records of
that unfinished instruction are allowed. Protected mode, hardware interrupts,
exceptions and processor resets are followed; the replay's counters for
them, and for the values Unicorn cannot judge for an 80286, are printed.

The last retired instruction must leave the CPU at STOP_CS:IP, the
boundary the runner reported, so Unicorn agrees on where the run stopped.
The BIOS's own POST tests that passed on the way are listed.
"""
import sys
from pathlib import Path

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
    # 8042 test, F000:03A2-0422: IN AL,60h / CMP AL,55h / JNZ error falls
    # through; the command-byte write is accepted; the test jumps on.
    '8042 self-test reply 55h': (0xf03db, 0x03dd),
    '8042 command byte accepted': (0xf03f7, 0x03fe),
    '8042 test complete': (0xf0402, 0x0422),
    # Protected-mode test: the INT 20h handler returns to F000:1C7A.
    'protected-mode software interrupt': (0xf1c7a, None),
    # Checkpoint 26h: STI, delay, CMP INTR_FLAG,0 / JZ taken.
    'no unexpected interrupt': (0xf0c84, 0x0c93),
    # Checkpoint 27h: OUT 82h,AX then both bytes read back; JZ taken.
    'page registers word write': (0xf0ca7, 0x0cae),
    # First instruction of the BIOS's temporary timer interrupt handler.
    'timer interrupt handler entered': (0xf1805, None),
}


def main():
    if len(sys.argv) not in (4, 5):
        raise SystemExit('usage: check_post_trace.py ROM TRACE STOP_CS:IP [ADAPTER_BASE:ADAPTER_ROM]')
    adapter_roms = []
    if len(sys.argv) == 5:
        base, _, path = sys.argv[4].partition(':')
        adapter_roms.append((int(base, 16), Path(path).read_bytes()))
    stop_cs, stop_ip = (int(part, 16) for part in sys.argv[3].split(':'))
    reached = []
    last_next = None

    def on_step(pc, next_ip, inputs):
        nonlocal last_next
        last_next = next_ip
        for name, (want_pc, want_ip) in CHECKPOINTS.items():
            if pc == want_pc and (want_ip is None or next_ip == want_ip) and name not in reached:
                reached.append(name)

    stats = {}
    steps, last_pc, trailing = replay(sys.argv[1], sys.argv[2], on_step, allow_trailing=True,
                                      stats=stats, adapter_roms=adapter_roms)
    # The BIOS stays in segment F000 for all code reached so far, so the
    # stop is checked as F000:IP; a far transfer elsewhere would fail here.
    if stop_cs != 0xf000 or last_next != stop_ip:
        raise ValueError(f'oracle ends at F000:{last_next or 0:04X}, runner reported {sys.argv[3]}')
    print(f'PASS: {steps} instruction states and data transfers match Unicorn up to '
          f'{sys.argv[3]}; {len(trailing)} data transfers in the unfinished instruction')
    missing = [name for name in CHECKPOINTS if name not in reached]
    if missing:
        raise ValueError('BIOS checkpoints not reached: ' + ', '.join(missing))
    print(f'POST tests passed ({len(reached)} of {len(CHECKPOINTS)}): ' + ', '.join(reached))
    print('events and non-oracle values: ' +
          ', '.join(f'{key}={value}' for key, value in sorted(stats.items())))


if __name__ == '__main__':
    main()
