#!/usr/bin/env python3
"""Self-test of the Unicorn replay's DMA (D) and A20 gate (G) records.

Usage: test_board_records.py ROM ADAPTER_BASE:ADAPTER_ROM TRACE [EXT_KB]

TRACE is a boot run's trace (scripts/run_boot_diskette.sh). The test cuts
it a little after the events below and replays each cut, unchanged and with
one record corrupted, in parallel; the unchanged cuts must pass and every
corrupted one must be rejected (design/intel_80286/scripts/bios_replay.py
documents the records and the ordering rule):

  boot-clean     the cut through the first boot-program instructions: pass
  boot-byte      the DMA byte stored at 0000:7C00 changed: the oracle runs
                 a different first instruction, rejected
  boot-dropped   every DMA record of the boot-sector read removed: rejected
  order          a DMA store at an address the same instruction read
                 earlier (inserted after the CPU's read, same value):
                 rejected by the ordering rule, although no value differs
  dma-read       the byte of a DMA memory read (the write test's sector)
                 changed: rejected by the comparison with the oracle's memory
  dma-outside    a DMA store moved outside RAM (to A0000h): rejected
  gate           (with EXT_KB > 0) a G 0 record inserted before the BIOS's
                 first store above 1 MB: the oracle folds it onto
                 the low address while the CPU stored above 1 MB, rejected
"""
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from bios_replay import replay


def lines_of(path):
    with open(path) as f:
        return f.readlines()


def cut_after(lines, index, extra_instructions):
    """The trace up to `extra_instructions` R records after line `index`."""
    seen = 0
    for n in range(index, len(lines)):
        if lines[n][0] == 'R':
            seen += 1
            if seen == extra_instructions:
                return lines[:n + 1]
    raise SystemExit('trace too short for the cut')


def run_case(args):
    name, rom, adapter, ext_kb, path = args
    try:
        replay(rom, path, allow_trailing=True, adapter_roms=adapter, ext_ram_kb=ext_kb)
        return name, None
    except (ValueError, SystemExit) as error:
        return name, str(error)[:160]


def main():
    if len(sys.argv) not in (4, 5):
        raise SystemExit(__doc__)
    rom = sys.argv[1]
    base, _, path = sys.argv[2].partition(':')
    adapter = [(int(base, 16), Path(path).read_bytes())]
    trace = sys.argv[3]
    ext_kb = int(sys.argv[4]) if len(sys.argv) == 5 else 0
    lines = lines_of(trace)
    out = Path(trace).parent / 'record_tests'
    out.mkdir(exist_ok=True)
    cases = {}

    first_boot = next(n for n, l in enumerate(lines) if l.startswith('D 7c00 '))
    boot_end = cut_after(lines, first_boot, 0) if False else None
    # The first instructions of the boot program (it begins at 7C00).
    start = next(n for n in range(first_boot, len(lines)) if lines[n].startswith('R 7c00 '))
    base_cut = cut_after(lines, start, 20)
    cases['boot-clean'] = (base_cut, True)
    bad = list(base_cut)
    _, a, v, w = bad[first_boot].split()
    bad[first_boot] = f'D {a} {int(v, 16) ^ 0x01:x} {w}\n'
    cases['boot-byte'] = (bad, False)
    cases['boot-dropped'] = ([l for n, l in enumerate(base_cut)
                              if not (l[0] == 'D' and 0x7c00 <= int(l.split()[1], 16) < 0x7e00)], False)

    # Ordering: the first CPU read of a byte that DMA stored (the sum loop).
    stored = set()
    order_at = None
    for n in range(first_boot, len(lines)):
        l = lines[n]
        if l[0] == 'D' and l.split()[3] == '1':
            stored.add(int(l.split()[1], 16))
        elif l[0] == 'B':
            _, a, v, w, io = l.split()
            if io == '0' and w == '0' and int(a, 16) in stored and int(a, 16) >= 0x10000:
                order_at = n
                break
    if order_at is None:
        raise SystemExit('no CPU read of DMA-stored data in the trace')
    _, a, v, _, _ = lines[order_at].split()
    order_cut = cut_after(lines, order_at, 3)
    clean_order = list(order_cut)
    cases['order-clean'] = (clean_order, True)
    cases['order'] = (order_cut[:order_at + 1] + [f'D {a} {v} 1\n'] + order_cut[order_at + 1:], False)

    # DMA memory reads (the write test).
    read_at = next((n for n in range(first_boot, len(lines)) if lines[n][0] == 'D' and
                    lines[n].split()[3] == '0'), None)
    if read_at is None:
        raise SystemExit('no DMA memory read in the trace')
    read_cut = cut_after(lines, read_at, 3)
    cases['dma-read-clean'] = (list(read_cut), True)
    bad = list(read_cut)
    _, a, v, w = bad[read_at].split()
    bad[read_at] = f'D {a} {int(v, 16) ^ 0x80:x} {w}\n'
    cases['dma-read'] = (bad, False)
    bad = list(base_cut)
    bad[first_boot] = f'D a0000 {int(lines[first_boot].split()[2], 16):x} 1\n'
    cases['dma-outside'] = (bad, False)

    if ext_kb:
        store = next((n for n, l in enumerate(lines) if l[0] == 'B' and l.split()[3] == '1' and
                      l.split()[4] == '0' and 0x100000 <= int(l.split()[1], 16) < 0x100000 + ext_kb * 1024),
                     None)
        if store is None:
            raise SystemExit('no store above 1 MB in the trace')
        # Insert before the store's instruction (after the previous R).
        prev = max(n for n in range(store) if lines[n][0] == 'R')
        gate_cut = cut_after(lines, store, 2)
        cases['gate-clean'] = (list(gate_cut), True)
        cases['gate'] = (gate_cut[:prev + 1] + ['G 0\n'] + gate_cut[prev + 1:], False)

    jobs = []
    for name, (content, _) in cases.items():
        p = out / f'{name}.txt'
        p.write_text(''.join(content))
        jobs.append((name, rom, adapter, ext_kb, str(p)))
    failures = 0
    with ProcessPoolExecutor(max_workers=len(jobs)) as pool:
        for name, error in pool.map(run_case, jobs):
            want_pass = cases[name][1]
            ok = (error is None) == want_pass
            failures += not ok
            verdict = 'passes' if error is None else f'rejected: {error}'
            print(f'{"ok  " if ok else "FAIL"} {name}: {verdict}')
    if failures:
        raise SystemExit(f'FAIL: {failures} record self-tests')
    print(f'PASS: {len(cases)} D/G record self-tests')


if __name__ == '__main__':
    main()
