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


def run_case(args):
    name, rom, adapter, ext_kb, path = args
    try:
        replay(rom, path, allow_trailing=True, adapter_roms=adapter, ext_ram_kb=ext_kb,
               no_coprocessor=True)
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

    first_boot = start = base_end = None
    first_boot_line = order_line = read_line = None
    stored = set()
    order_at = order_end = None
    read_at = read_end = None
    last_r = store = prev = gate_end = None
    base_seen = order_seen = read_seen = gate_seen = 0

    with open(trace) as f:
        for n, l in enumerate(f):
            is_r = l[0] == 'R'
            if ext_kb and store is None:
                if l[0] == 'B':
                    _, a, _, w, io = l.split()
                    if w == '1' and io == '0' and 0x100000 <= int(a, 16) < 0x100000 + ext_kb * 1024:
                        store = n
                        prev = last_r
            if ext_kb and store is not None and gate_end is None and is_r:
                gate_seen += 1
                if gate_seen == 2:
                    gate_end = n
            if is_r:
                last_r = n

            if first_boot is None:
                if l.startswith('D 7c00 '):
                    first_boot = n
                    first_boot_line = l
                else:
                    continue

            if start is None and l.startswith('R 7c00 '):
                start = n
            if start is not None and base_end is None and is_r:
                base_seen += 1
                if base_seen == 20:
                    base_end = n

            if order_at is None:
                if l[0] == 'D' and l.split()[3] == '1':
                    stored.add(int(l.split()[1], 16))
                elif l[0] == 'B':
                    _, a, _, w, io = l.split()
                    if io == '0' and w == '0' and int(a, 16) in stored and int(a, 16) >= 0x10000:
                        order_at = n
                        order_line = l
                        stored.clear()
            if order_at is not None and order_end is None and is_r:
                order_seen += 1
                if order_seen == 3:
                    order_end = n

            if read_at is None and l[0] == 'D' and l.split()[3] == '0':
                read_at = n
                read_line = l
            if read_at is not None and read_end is None and is_r:
                read_seen += 1
                if read_seen == 3:
                    read_end = n

            if (base_end is not None and order_end is not None and read_end is not None
                    and (not ext_kb or gate_end is not None)):
                break

    if first_boot is None or start is None or base_end is None:
        raise SystemExit('trace too short for boot cut')
    if order_at is None or order_end is None:
        raise SystemExit('no CPU read of DMA-stored data in the trace')
    if read_at is None or read_end is None:
        raise SystemExit('no DMA memory read in the trace')
    if ext_kb and (store is None or prev is None or gate_end is None):
        raise SystemExit('no store above 1 MB in the trace')

    out = Path(trace).parent / 'record_tests'
    out.mkdir(exist_ok=True)
    specs = [
        ('boot-clean', True, base_end),
        ('boot-byte', False, base_end),
        ('boot-dropped', False, base_end),
        ('dma-outside', False, base_end),
        ('order-clean', True, order_end),
        ('order', False, order_end),
        ('dma-read-clean', True, read_end),
        ('dma-read', False, read_end),
    ]
    if ext_kb:
        specs.extend([('gate-clean', True, gate_end), ('gate', False, gate_end)])

    cases = {name: want for name, want, _ in specs}
    jobs = [(name, rom, adapter, ext_kb, str(out / f'{name}.txt')) for name, _, _ in specs]

    _, fb_a, fb_v, fb_w = first_boot_line.split()
    boot_byte_line = f'D {fb_a} {int(fb_v, 16) ^ 0x01:x} {fb_w}\n'
    dma_outside_line = f'D a0000 {int(fb_v, 16):x} 1\n'
    _, oa_a, oa_v, _, _ = order_line.split()
    order_ins_line = f'D {oa_a} {oa_v} 1\n'
    _, rd_a, rd_v, rd_w = read_line.split()
    dma_read_line = f'D {rd_a} {int(rd_v, 16) ^ 0x80:x} {rd_w}\n'

    max_end = max(end for _, _, end in specs)
    files = {name: (out / f'{name}.txt').open('w') for name, _, _ in specs}
    try:
        with open(trace) as src:
            for n, l in enumerate(src):
                if n > max_end:
                    break
                if n <= base_end:
                    files['boot-clean'].write(l)
                    files['boot-byte'].write(boot_byte_line if n == first_boot else l)
                    if not (l[0] == 'D' and 0x7c00 <= int(l.split()[1], 16) < 0x7e00):
                        files['boot-dropped'].write(l)
                    files['dma-outside'].write(dma_outside_line if n == first_boot else l)
                if n <= order_end:
                    files['order-clean'].write(l)
                    files['order'].write(l)
                    if n == order_at:
                        files['order'].write(order_ins_line)
                if n <= read_end:
                    files['dma-read-clean'].write(l)
                    files['dma-read'].write(dma_read_line if n == read_at else l)
                if ext_kb and n <= gate_end:
                    files['gate-clean'].write(l)
                    files['gate'].write(l)
                    if n == prev:
                        files['gate'].write('G 0\n')
    finally:
        for fh in files.values():
            fh.close()

    failures = 0
    with ProcessPoolExecutor(max_workers=len(jobs)) as pool:
        for name, error in pool.map(run_case, jobs):
            want_pass = cases[name]
            ok = (error is None) == want_pass
            failures += not ok
            verdict = 'passes' if error is None else f'rejected: {error}'
            print(f'{"ok  " if ok else "FAIL"} {name}: {verdict}')
    if failures:
        raise SystemExit(f'FAIL: {failures} record self-tests')
    print(f'PASS: {len(cases)} D/G record self-tests')


if __name__ == '__main__':
    main()
