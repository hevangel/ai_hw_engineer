#!/usr/bin/env python3
"""Independent SCELBI-8B console simulator (SIMH i8008.c semantics).

Derived from simh/Intel-Systems/scelbi/i8008.c (Hans-Ake Lund, 2017) plus the
SCELBAL sc1.asm console routines.  Used only as a test oracle / debugger; it is
never loaded into the RTL.

The receive bit-banger follows SIMH's ttyin_d (scelbi_io.c) exactly: nine
INP 5 reads per character.  With a character pending, the first INP returns the
start bit (0) and latches the byte; the next eight return the data bits LSB
first in bit 7.  With nothing pending, the line reads idle (0x80) and any
partial frame is abandoned, matching SIMH's `bitcntr = 0` reset.
"""
import sys
from pathlib import Path

MEM = bytearray(0x4000)
STACK = [0] * 8
tty_in = bytearray()
tty_log = bytearray()
out_ports = {}
in_ports = {}
STATS = {"reads": 0, "writes": 0, "inputs": 0, "outputs": 0}


class Cpu:
    def reset(self):
        self.a = self.b = self.c = self.d = self.e = 0
        self.hl = 0
        self.sp = 0
        self.pc = 0
        self.cf = self.zf = self.sf = self.pf = 0
        self.stack = [0] * 8
        self.halted = False
        self.rx_shift = None
        self.rx_bit = 0
        self.tx_shift = 0
        self.tx_bits = 0
        for k in STATS:
            STATS[k] = 0

    def getreg(self, r):
        return (self.a, self.b, self.c, self.d, self.e,
                (self.hl >> 8) & 0xFF, self.hl & 0xFF, 0)[r]

    def putreg(self, r, v):
        v &= 0xFF
        if r == 0: self.a = v
        elif r == 1: self.b = v
        elif r == 2: self.c = v
        elif r == 3: self.d = v
        elif r == 4: self.e = v
        elif r == 5: self.hl = (self.hl & 0x00FF) | (v << 8)
        elif r == 6: self.hl = (self.hl & 0xFF00) | v

    def cond(self, con):
        return (self.cf, self.zf, self.sf, self.pf)[con] == 1

    def parity(self, v):
        return 1 if bin(v & 0xFF).count("1") % 2 == 0 else 0

    def szp(self, v):
        v &= 0xFF
        self.zf = 1 if v == 0 else 0
        self.sf = (v >> 7) & 1
        self.pf = self.parity(v)

    def setarith(self, v):
        self.cf = 1 if v & 0x100 else 0
        self.szp(v)

    def setlogical(self, v):
        self.cf = 0
        self.szp(v)

    def setinc(self, v):
        self.szp(v)

    def alu(self, kind, value):
        a = self.a
        if kind == 0: r = a + value
        elif kind == 1: r = a + value + self.cf
        elif kind == 2: r = a - value
        elif kind == 3: r = a - value - self.cf
        elif kind == 4: r = a & value
        elif kind == 5: r = a ^ value
        elif kind == 6: r = a | value
        else: r = a - value
        self.cf = 1 if (kind < 4 or kind == 7) and (r & 0x100) else 0
        self.szp(r)
        if kind != 7:
            self.a = r & 0xFF

    def push(self, v):
        self.stack[self.sp] = v & 0x3FFF
        self.sp = (self.sp + 1) & 7

    def pop(self):
        self.sp = (self.sp - 1) & 7
        return self.stack[self.sp]

    # --- console card (SCELBI bit-banger) -------------------------------
    def inp(self, port):
        STATS["inputs"] += 1
        if port in in_ports:
            return in_ports[port]()
        if port == 5:
            # SIMH ttyin_d exactly. bitcntr 0: if a byte is queued, latch it
            # (with bit 7 forced, the SCELBI 7-bit console convention), clear
            # the flag, and return the start bit; otherwise return idle (0x80).
            # bitcntr 1..8 then return the eight data bits LSB first, and the
            # frame ends regardless of what the host has queued -- the byte was
            # already latched, so a mid-frame empty queue must not reset it.
            if self.rx_bit == 0:
                if not tty_in:
                    self.rx_shift = None
                    return 0x80
                self.rx_shift = tty_in.pop(0) | 0x80
                self.rx_bit = 1
                return 0x00
            if self.rx_bit > 7:
                bit = self.rx_shift & 1
                self.rx_shift = None
                self.rx_bit = 0
                return bit << 7
            bit = self.rx_shift & 1
            self.rx_shift >>= 1
            self.rx_bit += 1
            return bit << 7
        return 0x80

    def out(self, port, value):
        STATS["outputs"] += 1
        out_ports[port] = value
        if port != 14:
            return
        # SIMH ttyout_d: 10 OUTs per character (start, 8 data LSB first in bit
        # 0, stop). charout accumulates the data bits with 0x80 OR-ed in, so it
        # is a full 8-bit value; the printed byte is charout & 0x7f, and 0x14
        # (CTRL-T) is not printed.
        if self.tx_bits == 0 and (value & 1) == 0:
            self.tx_bits = 1
            return
        if self.tx_bits == 8:
            self.tx_shift >>= 1
            if value & 1:
                self.tx_shift |= 0x80
            if (self.tx_shift & 0xFF) != 0x14:
                tty_log.append(self.tx_shift & 0x7F)
            self.tx_bits = 9
            return
        if self.tx_bits > 8:
            self.tx_shift = 0
            self.tx_bits = 0
            return
        self.tx_shift >>= 1
        if value & 1:
            self.tx_shift |= 0x80
        self.tx_bits += 1

    def step(self):
        op = MEM[self.pc]
        pc = (self.pc + 1) & 0x3FFF
        if op in (0x00, 0x01, 0xFF):
            self.halted = True
            self.pc = pc
            return
        if op & 0xC7 == 0xC7:
            self.putreg((op >> 3) & 7, MEM[self.hl & 0x3FFF]); self.pc = pc; return
        if op & 0xF8 == 0xF8:
            MEM[self.hl & 0x3FFF] = self.getreg(op & 7); self.pc = pc; return
        if op & 0xC0 == 0xC0:
            self.putreg((op >> 3) & 7, self.getreg(op & 7)); self.pc = pc; return
        if op == 0x3E:
            MEM[self.hl & 0x3FFF] = MEM[pc]; self.pc = (pc + 1) & 0x3FFF; return
        if op & 0xC7 == 0x06:
            self.putreg((op >> 3) & 7, MEM[pc]); self.pc = (pc + 1) & 0x3FFF; return
        if op & 0xC7 == 0x00:
            v = self.getreg((op >> 3) & 7) + 1; self.setinc(v); self.putreg((op >> 3) & 7, v); self.pc = pc; return
        if op & 0xC7 == 0x01:
            v = self.getreg((op >> 3) & 7) - 1; self.setinc(v); self.putreg((op >> 3) & 7, v); self.pc = pc; return
        if op & 0xC0 == 0x80:
            self.alu((op >> 3) & 7, MEM[self.hl & 0x3FFF] if op & 7 == 7 else self.getreg(op & 7)); self.pc = pc; return
        if op & 0xC7 == 0x44:
            self.pc = (MEM[pc + 1] << 8) | MEM[pc]; return
        if op & 0xE7 in (0x40, 0x60):
            taken = self.cond((op >> 3) & 3) == ((op >> 5) & 1)
            self.pc = ((MEM[pc + 1] << 8) | MEM[pc]) if taken else (pc + 2) & 0x3FFF
            return
        if op & 0xC7 == 0x46:
            self.pc = (pc + 2) & 0x3FFF
            self.push(self.pc)
            self.pc = (MEM[pc + 1] << 8) | MEM[pc]; return
        if op & 0xE7 in (0x42, 0x62):
            if self.cond((op >> 3) & 3) == ((op >> 5) & 1):
                self.pc = (pc + 2) & 0x3FFF
                self.push(self.pc)
                self.pc = (MEM[pc + 1] << 8) | MEM[pc]
            else:
                self.pc = (pc + 2) & 0x3FFF
            return
        if op & 0xC7 == 0x07:
            self.pc = self.pop(); return
        if op & 0xE7 in (0x03, 0x23):
            if self.cond((op >> 3) & 3) == ((op >> 5) & 1):
                self.pc = self.pop()
            self.pc = pc if not (op & 0xE7 in (0x03, 0x23) and self.cond((op >> 3) & 3) == ((op >> 5) & 1)) else self.pc
            return
        if op & 0xC7 == 0x05:
            self.push(pc); self.pc = op & 0x38; return
        if op & 0xC1 == 0x41:
            port = (op & 0x3E) >> 1
            if port < 8:
                self.putreg(0, self.inp(port))
            else:
                self.out(port, self.a)
            self.pc = pc; return
        if op & 0xC7 == 0x04:
            self.alu((op >> 3) & 7, MEM[pc]); self.pc = (pc + 1) & 0x3FFF; return
        if op == 0x02:
            self.cf = self.a >> 7; self.a = ((self.a << 1) | self.cf) & 0xFF; self.pc = pc; return
        if op == 0x0A:
            self.cf = self.a & 1; self.a = (self.a >> 1) | (self.cf << 7); self.pc = pc; return
        if op == 0x12:
            old = self.cf; self.cf = self.a >> 7; self.a = ((self.a << 1) | old) & 0xFF; self.pc = pc; return
        if op == 0x1A:
            old = self.cf; self.cf = self.a & 1; self.a = (self.a >> 1) | (old << 7); self.pc = pc; return
        raise RuntimeError(f"unmodelled opcode {op:02x} at {(pc-1)&0x3FFF:04x}")


cpu = Cpu()


def reset(image=None):
    global tty_in, tty_log
    cpu.reset()
    MEM[:] = [0] * 0x4000
    here = Path(__file__).resolve().parent
    default = here.parent / "src/rom/scelbal_sc1.bin"
    program = Path(image) if image else default
    data = open(program, "rb").read()
    MEM[0x40:0x40 + len(data)] = data
    MEM[0:3] = [0x44, 0x40, 0x00]
    tty_in = bytearray()
    tty_log = bytearray()


if __name__ == "__main__":
    # Minimal manual CLI: feed the console from stdin, run until it goes
    # quiet, and print what SCELBAL sent back. Bounded so a hang is visible.
    import argparse

    parser = argparse.ArgumentParser(description="SCELBI 8B console oracle")
    parser.add_argument("input", nargs="?", help="text to type into SCELBAL")
    parser.add_argument("--max-instructions", type=int, default=2_000_000)
    args = parser.parse_args()

    reset()
    text = (args.input or "").encode().replace(b"\n", b"\r")
    tty_in.extend(text)

    n = 0
    quiet = 0
    last = len(tty_log)
    while not cpu.halted and n < args.max_instructions:
        cpu.step()
        n += 1
        if len(tty_log) != last:
            last = len(tty_log)
            quiet = 0
        else:
            quiet += 1
            if n > 200000 and quiet > 400000:
                break
    sys.stdout.buffer.write(bytes(b & 0x7F for b in tty_log))
    sys.stdout.flush()
    print(f"\n[{n} instructions, {'halted' if cpu.halted else 'quiet'}]",
          file=sys.stderr)