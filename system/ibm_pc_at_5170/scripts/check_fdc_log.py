#!/usr/bin/env python3
"""Check the diskette adapter's traffic in a POST/boot trace against an
independent model of the IBM AT diskette function.

Usage: check_fdc_log.py TRACE --fda=IMG [--fda-type=1.2|360] [--fdb=IMG ...]
                        [--final-a=IMG] [--final-b=IMG]

The model is written from the documents, not from the RTL: the adapter's
registers (IBM PC AT Technical Reference 1502494, Fixed Disk and Diskette
Adapter, PDF 611-613 and 628: DOR 3F2h, main status 3F4h, data 3F5h,
digital input 3F7h read, data rate 3F7h write), the NEC uPD765 / Intel 8272A
command and result protocol (Intel 8272A data sheet, order 210806-001,
Table 4 and the status register definitions, also on Technical Reference PDF
614-628) and the drive behaviour the specification states for this system
(assumption AT34: decoded sectors, readable only at the medium's data rate,
the change line, track 0, stepping).

It reads the runner's trace (B records for the I/O ports 3F2h-3F7h, D
records for DMA memory transfers; everything else is ignored) and checks:
  - every byte the CPU reads from 3F5h (results) equals the model's;
  - main-status reads are consistent with the model's phase whenever they
    show RQM (direction bit, controller busy bit);
  - digital-input bit 7 equals the selected drive's change line;
  - every DMA byte of a read command is the image byte of the sector the
    controller is reading, at consecutive memory addresses; every DMA byte
    of a write command is written to the model's image;
  - with --final-a/--final-b, the image the runner wrote back equals the
    model's image.
What it does not check: timing (when RQM is set, when the seek bits clear,
interrupt latency), or a read's exact terminal count when the DMA verify
mode moves no bytes (then any whole number of sectors is accepted).
"""
import argparse
import sys
from pathlib import Path

GEOMETRY = {1228800: (80, 15, True), 368640: (40, 9, False), 327680: (40, 8, False)}


class Drive:
    def __init__(self, image, kind):
        self.kind = kind                       # '1.2' or '360' or None
        self.image = bytearray(image) if image is not None else None
        self.position = 0
        self.changed = True
        if self.image is not None:
            self.cylinders, self.spt, self.hd = GEOMETRY[len(self.image)]

    def readable_rate(self):
        if self.image is None or self.kind is None:
            return None
        if self.hd:
            return 0 if self.kind == '1.2' else None
        return 1 if self.kind == '1.2' else 2

    def track(self):
        if self.hd or self.kind == '360':
            return self.position if self.position < self.cylinders else None
        if self.position & 1:
            return None
        return self.position // 2 if self.position // 2 < self.cylinders else None

    def max_position(self):
        return (80 if self.kind == '1.2' else 40) + 3

    def step(self, delta):
        target = min(max(self.position + delta, 0), self.max_position())
        self.position = target
        if delta and self.image is not None:
            self.changed = False

    def offset(self, c, h, r):
        return ((c * 2 + h) * self.spt + (r - 1)) * 512


class Model:
    LENGTH = {0x02: 9, 0x03: 3, 0x04: 2, 0x05: 9, 0x06: 9, 0x07: 2, 0x08: 1, 0x09: 9,
              0x0a: 2, 0x0c: 9, 0x0d: 6, 0x0f: 3, 0x11: 9, 0x19: 9, 0x1d: 9}

    def __init__(self, drives):
        self.drives = drives
        self.dor = 0
        self.rate = 0
        self.reset_controller()
        self.stats = dict(commands={}, results=0, dma_read_bytes=0, dma_write_bytes=0, msr_reads=0,
                          dir_reads=0, resets=0)

    def reset_controller(self):
        self.phase = 'idle'          # idle, command, exec, result
        self.command = []
        self.results = []
        self.events = {}             # unit -> (st0, pcn)
        self.pcn = [0, 0, 0, 0]
        self.exec = None

    def selected(self):
        unit = self.dor & 1
        if self.dor & (0x10 << unit):
            return self.drives[unit]
        return None

    def fail(self, where, text):
        raise SystemExit(f'FAIL: {where}: {text}')

    # -- registers -------------------------------------------------------
    def write_dor(self, value, where):
        old = self.dor
        self.dor = value
        if not value & 4:
            self.reset_controller()
        elif not old & 4:
            # Reset released: the initial drive polling reports a READY
            # change for every unit (ST0 = C0h + unit, PCN 0).
            self.reset_controller()
            self.events = {u: (0xc0 | u, 0) for u in range(4)}
            self.stats['resets'] += 1

    def read_dir(self, value, where):
        self.stats['dir_reads'] += 1
        drive = self.selected()
        change = bool(drive and drive.kind and drive.changed)
        if bool(value & 0x80) != change or value & 0x7f != 0x7f:
            self.fail(where, f'digital input {value:02x}, model change line {int(change)}')

    def read_msr(self, value, where):
        self.stats['msr_reads'] += 1
        if not value & 0x80:
            return
        if self.phase == 'exec':
            # DMA mode never requests the CPU during execution; the result
            # phase begins when the controller finishes (model: now).
            self.finish_exec(where)
        dio = bool(value & 0x40)
        if dio != (self.phase == 'result'):
            self.fail(where, f'main status {value:02x} in model phase {self.phase}')
        if bool(value & 0x10) != (self.phase in ('command', 'result')):
            self.fail(where, f'main status {value:02x}: busy bit, model phase {self.phase}')

    def read_data(self, value, where):
        if self.phase == 'exec':
            self.finish_exec(where)
        if self.phase != 'result' or not self.results:
            self.fail(where, f'data register read {value:02x} with no result pending (phase {self.phase})')
        want = self.results.pop(0)
        self.stats['results'] += 1
        if want is not None and value != want:
            self.fail(where, f'result byte {value:02x}, model {want:02x} (command {self.last:02x})')
        if callable(self.exec_check):
            self.exec_check(value)
        if not self.results:
            self.phase = 'idle'

    def write_data(self, value, where):
        if self.phase == 'exec':
            self.fail(where, f'data register write {value:02x} during execution')
        if self.phase == 'result':
            self.fail(where, f'data register write {value:02x} in the result phase')
        self.command.append(value)
        self.phase = 'command'
        op = self.command[0] & 0x1f
        if len(self.command) >= self.LENGTH.get(op, 1):
            self.run_command(where)

    # -- commands --------------------------------------------------------
    def run_command(self, where):
        cmd, self.command = self.command, []
        op = cmd[0] & 0x1f
        self.last = cmd[0]
        self.exec_check = None
        name = {3: 'specify', 4: 'sense drive', 6: 'read', 5: 'write', 7: 'recalibrate', 8: 'sense interrupt',
                0xf: 'seek', 0xa: 'read id', 0xd: 'format'}.get(op, f'{cmd[0]:02x}')
        self.stats['commands'][name] = self.stats['commands'].get(name, 0) + 1
        valid = op in self.LENGTH and (op not in (3, 4, 7, 8, 0xf) or cmd[0] & 0xe0 == 0)
        completed_seek = any(st0 & 0x20 for st0, _ in self.events.values())
        if not valid or (completed_seek and cmd[0] != 8):
            self.results = [0x80]
            self.phase = 'result'
            return
        if op == 3:
            if cmd[2] & 1:
                self.fail(where, 'SPECIFY selects non-DMA mode, which the AT BIOS does not use')
            self.phase = 'idle'
        elif op == 4:
            drive = self.selected()
            st3 = 0x20 | (cmd[1] & 7)
            if drive and drive.kind:
                st3 |= 0x40 if drive.image is not None and getattr(drive, 'read_only', False) else 0
                st3 |= 0x10 if drive.position == 0 else 0
            self.results = [st3]
            self.phase = 'result'
        elif op == 8:
            if not self.events:
                self.results = [0x80]
            else:
                unit = min(self.events)
                st0, pcn = self.events.pop(unit)
                self.results = [st0, pcn]
            self.phase = 'result'
        elif op in (7, 0xf):
            unit = cmd[1] & 3
            drive = self.selected()
            if op == 7:
                if drive and drive.kind:
                    steps = min(drive.position, 77)
                    if steps:
                        drive.step(-steps)
                    ok = drive.position == 0
                else:
                    ok = False
                self.pcn[unit] = 0
                self.events[unit] = (0x20 | unit, 0) if ok else (0x70 | unit, 0)
            else:
                delta = cmd[2] - self.pcn[unit]
                if drive and drive.kind and delta:
                    drive.step(delta)
                self.pcn[unit] = cmd[2]
                self.events[unit] = (0x20 | unit, cmd[2])
            self.phase = 'idle'
        elif op in (5, 6):
            self.start_transfer(cmd, where)
        elif op == 0xa:
            drive = self.selected()
            head = (cmd[1] >> 2) & 1
            unit_hd = cmd[1] & 7
            if drive and drive.readable_rate() == self.rate and drive.track() is not None:
                track = drive.track()
                self.results = [unit_hd, 0, 0, track, head, None, 2]
                self.exec_check = None
            else:
                self.results = [0x40 | unit_hd, 0x05, 0, None, None, None, None]
            self.phase = 'result'
        else:
            self.fail(where, f'command {cmd[0]:02x} is not modeled by this checker')

    def start_transfer(self, cmd, where):
        write = cmd[0] & 0x1f == 5
        mt = bool(cmd[0] & 0x80)
        unit_hd = cmd[1] & 7
        c, h, r, n, eot = cmd[2], cmd[3], cmd[4], cmd[5], cmd[6]
        drive = self.selected()
        self.exec = dict(write=write, mt=mt, unit_hd=unit_hd, c=c, h=h, r=r, n=n, eot=eot, bytes=0,
                         addr=None, drive=drive, error=None)
        e = self.exec
        if n != 2:
            self.fail(where, f'sector size code {n} (only 512-byte sectors are modeled)')
        readable = drive is not None and drive.kind and drive.readable_rate() == self.rate and \
            drive.track() is not None
        if write and drive is not None and drive.image is not None and drive.read_only:
            e['error'] = [0x40 | unit_hd, 0x02, 0, c, h, r, n]
        elif not readable:
            # No ID at this data rate or position: two index pulses with no
            # header give ND + MA.
            e['error'] = [0x40 | unit_hd, 0x05, 0, c, h, r, n]
        elif drive.track() != c:
            # The recorded cylinder differs: wrong cylinder (ND, WC, BC if FFh).
            t = drive.track()
            if not 1 <= r <= drive.spt:
                e['error'] = [0x40 | unit_hd, 0x04, 0, c, h, r, n]
            else:
                e['error'] = [0x40 | unit_hd, 0x04, 0x10 | (0x02 if t == 0xff else 0), t, (cmd[1] >> 2) & 1, r, n]
        elif not 1 <= r <= drive.spt or h != (cmd[1] >> 2) & 1:
            e['error'] = [0x40 | unit_hd, 0x04, 0, c, h, r, n]
        self.phase = 'exec'

    def dma(self, address, value, write, where):
        e = self.exec
        if self.phase != 'exec' or e is None or e['error'] is not None:
            self.fail(where, f'DMA transfer {address:06x}={value:02x} with no diskette transfer in progress')
        if e['addr'] is not None and address != e['addr'] + 1:
            self.fail(where, f'DMA address {address:06x} after {e["addr"]:06x}')
        e['addr'] = address
        drive = e['drive']
        # Current sector from the bytes moved so far.
        index = e['bytes'] // 512
        c, h, r = self.position_after(index, where)
        offset = drive.offset(c, h, r) + e['bytes'] % 512
        if e['write']:
            if write:
                self.fail(where, 'DMA wrote memory during a diskette write')
            drive.image[offset] = value
            self.stats['dma_read_bytes'] += 1
        else:
            if not write:
                self.fail(where, 'DMA read memory during a diskette read')
            if drive.image[offset] != value:
                self.fail(where, f'DMA byte {value:02x} at {address:06x}, image C{c} H{h} R{r} '
                                 f'byte {e["bytes"] % 512} is {drive.image[offset]:02x}')
            self.stats['dma_write_bytes'] += 1
        e['bytes'] += 1

    def position_after(self, index, where):
        """(c, h, r) of the index-th sector of the transfer (8272 Table 8 / MT)."""
        e = self.exec
        c, h, r = e['c'], e['h'], e['r']
        for _ in range(index):
            if r == e['eot']:
                if e['mt'] and h == 0:
                    h, r = 1, 1
                else:
                    self.fail(where, 'transfer continues past the end of the cylinder')
            else:
                r += 1
        return c, h, r

    def finish_exec(self, where):
        e = self.exec
        self.phase = 'result'
        if e['error'] is not None:
            self.results = list(e['error'])
            return
        if e['bytes'] % 512:
            self.fail(where, f'transfer ended after {e["bytes"]} bytes, not whole sectors')
        count = e['bytes'] // 512
        if count == 0:
            # DMA verify (no memory strobes): the result reports where TC
            # stopped the read, unknown here.
            self.results = [None] * 7
            return
        c, h, r = self.position_after(count - 1, where)
        # TC ended the command after sector (c, h, r) (Intel Table 8).
        if r != e['eot']:
            nc, nh, nr = c, h, r + 1
        elif e['mt'] and h == 0:
            nc, nh, nr = c, 1, 1
        else:
            nc, nh, nr = c + 1, 0 if e['mt'] else h, 1
        self.results = [(e['unit_hd'] & 3) | (h << 2), 0, 0, nc, nh, nr, e['n']]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('trace')
    for u in 'ab':
        parser.add_argument(f'--fd{u}')
        parser.add_argument(f'--fd{u}-type')
        parser.add_argument(f'--fd{u}-ro', action='store_true')
        parser.add_argument(f'--final-{u}')
    args = parser.parse_args()
    drives = []
    for u in 'ab':
        path = getattr(args, f'fd{u}')
        kind = getattr(args, f'fd{u}_type') or ('1.2' if u == 'a' or path else None)
        image = Path(path).read_bytes() if path else None
        d = Drive(image, kind)
        d.read_only = getattr(args, f'fd{u}_ro')
        drives.append(d)
    model = Model(drives)
    step = 0
    with open(args.trace) as trace:
        for number, line in enumerate(trace, 1):
            kind = line[0]
            if kind == 'R':
                step += 1
                continue
            where = f'trace line {number} (instruction {step + 1})'
            if kind == 'D':
                _, a, v, w = line.split()
                model.dma(int(a, 16), int(v, 16), w == '1', where)
            elif kind == 'B':
                _, a, v, w, io = line.split()
                if io != '1':
                    continue
                port, value, write = int(a, 16) & 0x3ff, int(v, 16), w == '1'
                if port == 0x3f2 and write:
                    model.write_dor(value, where)
                elif port == 0x3f7:
                    if write:
                        model.rate = value & 3
                    else:
                        model.read_dir(value, where)
                elif port == 0x3f4 and not write:
                    model.read_msr(value, where)
                elif port == 0x3f5:
                    if write:
                        model.write_data(value, where)
                    else:
                        model.read_data(value, where)
    for u, d in zip('ab', drives):
        final = getattr(args, f'final_{u}')
        if final:
            got = Path(final).read_bytes()
            if got != bytes(d.image):
                diff = next(i for i in range(len(got)) if got[i] != d.image[i])
                raise SystemExit(f'FAIL: drive {u.upper()} image differs from the model at byte {diff}')
            print(f'drive {u.upper()}: the written-back image equals the model\'s image')
    s = model.stats
    if not s['commands']:
        raise SystemExit('FAIL: no diskette controller command in the trace')
    print(f'PASS: diskette adapter and controller traffic matches the model: {s["results"]} result bytes, '
          f'{s["dma_write_bytes"]} DMA bytes read from diskette into memory, {s["dma_read_bytes"]} written '
          f'from memory to diskette, {s["msr_reads"]} status reads, {s["dir_reads"]} digital input reads, '
          f'{s["resets"]} controller resets; commands ' +
          ', '.join(f'{k}={v}' for k, v in sorted(s['commands'].items())))


if __name__ == '__main__':
    main()
