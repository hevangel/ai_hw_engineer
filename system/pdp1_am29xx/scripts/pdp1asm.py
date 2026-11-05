#!/usr/bin/env python3
"""Small PDP-1 assembler for tests, the panel demos and the oracle diff.

Encodings follow DEC F-16 (September 1961): the six-digit octal instruction
word is `field<<12 | address`, where `field = opcode<<1 | indirect`.

Usage:
    python3 scripts/pdp1asm.py program.pdp1 --hex out.hex [--listing out.lst]

Source syntax (one instruction per line; `;` starts a comment):
    label:  mnemonic [operand]
    .org 0o1000
    .word 0o1234            raw 18-bit word
Operands are octal by default (DEC convention), `0x..` hex, or a label.
Negative literals (`-20000`) use the PDP-1 one's-complement minus form.
"""
from __future__ import annotations

import argparse
import re
import sys

MEMORY_REF = {
    "and": 0o01, "ior": 0o02, "xor": 0o03, "xct": 0o04,
    "lac": 0o10, "lio": 0o11, "dac": 0o12, "dap": 0o13, "dip": 0o14,
    "dio": 0o15, "dzm": 0o16, "add": 0o20, "sub": 0o21, "idx": 0o22,
    "isp": 0o23, "sad": 0o24, "sas": 0o25, "mus": 0o26, "dis": 0o27,
    "jmp": 0o30, "jsp": 0o31,
}

# Skip group: name -> address-field bits.
SKIPS = {
    "sza": 0o100, "spa": 0o200, "sma": 0o400, "szo": 0o1000, "spi": 0o2000,
}
# Operate group.
OPERATES = {
    "cla": 0o200, "hlt": 0o400, "cma": 0o1000, "lat": 0o2000, "cli": 0o4000,
}
# Shift subcode (IR<12:9>).
SHIFTS = {
    "ral": 1, "ril": 2, "rcl": 3, "sal": 5, "sil": 6, "scl": 7,
    "rar": 9, "rir": 10, "rcr": 11, "sar": 13, "sir": 14, "scr": 15,
}
# I/O devices.
DEVICES = {
    "rpa": 0o01, "rpb": 0o02, "tyo": 0o03, "tyi": 0o04, "ppa": 0o05,
    "ppb": 0o06, "dpy": 0o07, "tyc": 0o11, "rrb": 0o30, "cks": 0o33,
    "lsm": 0o54, "esm": 0o55,
}


class Assembler:
    def __init__(self) -> None:
        self.words: dict[int, int] = {}
        self.labels: dict[str, int] = {}
        self.address = 0
        self.listing: list[str] = []

    def value(self, text: str) -> int:
        text = text.strip()
        if text.startswith("-"):
            raw = self.value(text[1:])
            return (~raw) & 0o777777
        if text.startswith("("):
            return self.value(text[1:].rstrip(")"))
        if text in self.labels:
            return self.labels[text]
        if text.startswith("0o"):
            return int(text, 8)
        if text.startswith("0x"):
            return int(text, 16)
        if text.startswith("0b"):
            return int(text, 2)
        if re.fullmatch(r"[0-7]+", text):
            return int(text, 8)
        if re.fullmatch(r"\d+", text):
            return int(text, 10)
        raise ValueError(f"cannot evaluate {text!r}")

    def emit(self, word: int, source: str) -> None:
        self.words[self.address] = word & 0o777777
        self.listing.append(f"{self.address:04o}  {word & 0o777777:06o}  {source}")
        self.address = (self.address + 1) & 0o7777

    def assemble(self, text: str) -> None:
        lines = []
        for raw in text.splitlines():
            line = raw.split(";", 1)[0].rstrip()
            if not line.strip():
                continue
            label = ""
            m = re.match(r"^\s*([A-Za-z_.][\w.]*)\s*:\s*(.*)$", line)
            if m:
                label = m.group(1).lower()
                line = m.group(2).strip()
            line = line.strip()
            lines.append((label, line, raw.strip()))

        # First pass: assign addresses.
        address = 0
        placed = []
        for label, line, raw in lines:
            if line.startswith(".org"):
                address = self.value(line.split(None, 1)[1])
            if label:
                self.labels[label] = address
            placed.append((address, label, line, raw))
            if line and not line.startswith(".org") and not line.startswith(".="):
                address = (address + 1) & 0o7777
        self.words.clear()
        self.listing.clear()
        for address, label, line, raw in placed:
            self.address = address
            if not line:
                continue
            if line.startswith(".org"):
                continue
            if line.startswith(".word"):
                self.emit(self.value(line.split(None, 1)[1]), raw)
                continue
            self.instruction(line, raw)

    def instruction(self, line: str, raw: str) -> None:
        parts = line.replace(",", " ").split()
        mnemonic = parts[0].lower()
        indirect = False
        if mnemonic == "i" and len(parts) > 1:
            indirect = True
            mnemonic = parts[1].lower()
            parts = parts[1:]
        operand = parts[1] if len(parts) > 1 else "0"
        if len(parts) > 2 and parts[1].lower() == "i":
            indirect = True
            operand = parts[2]
        if mnemonic.endswith("i") and mnemonic[:-1] in MEMORY_REF:
            mnemonic, indirect = mnemonic[:-1], True

        if mnemonic in MEMORY_REF:
            op = MEMORY_REF[mnemonic]
            addr = self.value(operand) & 0o7777
            self.emit((op << 13) | (int(indirect) << 12) | addr, raw)
            return
        if mnemonic == "cal":
            self.emit((0o07 << 13) | 0o100, raw)
            return
        if mnemonic == "jda":
            addr = self.value(operand) & 0o7777
            self.emit((0o07 << 13) | (1 << 12) | addr, raw)
            return
        if mnemonic == "law":
            n = self.value(operand) & 0o7777
            self.emit((0o34 << 13) | (int(indirect) << 12) | n, raw)
            return
        if mnemonic in SKIPS:
            addr = SKIPS[mnemonic]
            if operand and len(parts) > 1 and parts[1].lower() not in ("i",):
                addr |= self.sense_value(operand)
            self.emit((0o32 << 13) | (int(indirect) << 12) | (addr & 0o7777), raw)
            return
        if mnemonic in ("szs", "szf") or mnemonic.startswith(("szs", "szf")):
            base = 0o10 if mnemonic.startswith("szs") else 0o1
            index = self.value(operand) & 0o7 if operand else 0
            self.emit((0o32 << 13) | (int(indirect) << 12) | (base * index), raw)
            return
        if mnemonic in SHIFTS:
            count = self.value(operand) & 0o777 if operand else 0
            if count == 0:
                count = 1
            steps = bin(count).count("1")
            field = (steps & 0o777)
            self.emit((0o33 << 13) | (SHIFTS[mnemonic] << 9) | field, raw)
            return
        if mnemonic in OPERATES:
            self.emit((0o37 << 13) | OPERATES[mnemonic], raw)
            return
        if mnemonic in ("nop", "opr"):
            self.emit((0o37 << 13) | (self.value(operand) & 0o7777 if operand else 0), raw)
            return
        if mnemonic in ("clf", "stf"):
            flag = self.value(operand) & 0o7
            value = (0o1 if mnemonic == "clf" else 0o11) + flag
            self.emit((0o37 << 13) | value, raw)
            return
        if mnemonic in DEVICES:
            wait = int(indirect)
            wait_bit = 0
            self.emit((0o35 << 13) | (wait << 12) | DEVICES[mnemonic], raw)
            return
        if mnemonic in ("iot", "ioti"):
            # iot <device> [pulse]
            dev = (DEVICES[parts[1]] if parts[1] in DEVICES else self.value(parts[1]) & 0o77) if len(parts) > 1 else 0
            pulse = self.value(parts[2]) & 0o77 if len(parts) > 2 else 0
            self.emit((0o35 << 13) | (int(mnemonic == "ioti") << 12) |
                      (int(indirect) << 12) | (pulse << 6) | dev, raw)
            return
        raise ValueError(f"unknown mnemonic {mnemonic!r} in {raw!r}")

    @staticmethod
    def sense_value(text: str) -> int:
        return 0

    def hex_image(self) -> str:
        return "".join(f"{addr:04o} {word:06o}\n" for addr, word in sorted(self.words.items()))

    def word_list(self) -> list[int]:
        size = (max(self.words) + 1) if self.words else 0
        return [self.words.get(i, 0) for i in range(size)]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("--hex", required=True)
    parser.add_argument("--listing")
    args = parser.parse_args(argv[1:])
    with open(args.source, "r", encoding="utf-8") as handle:
        text = handle.read()
    asm = Assembler()
    asm.assemble(text)
    with open(args.hex, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(asm.hex_image())
    if args.listing:
        with open(args.listing, "w", encoding="utf-8", newline="\n") as handle:
            handle.write("\n".join(asm.listing) + "\n")
    print(f"{len(asm.words)} words -> {args.hex}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
