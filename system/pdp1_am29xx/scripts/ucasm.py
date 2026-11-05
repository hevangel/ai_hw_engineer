#!/usr/bin/env python3
"""Assemble the PDP-1 Am29xx microcode control store.

The assembler is the single source of truth for the control-word layout: it
emits both the SystemVerilog struct definition and the ROM module, so the RTL
cannot drift from the encoding.

Usage:
    python3 scripts/ucasm.py src/microcode/pdp1_uc.uc src/microcode/pdp1_uc.sv

Input format:
    ; comment
    @org 0x0000          place the next words at this microaddress
    LABEL:               define a label
    LABEL: field=value, flag, ...
    @fill illegal        set the fill word (default: continue with no action)

Numbers are decimal or 0o-prefixed octal (0x hex accepted).
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field

# ---------------------------------------------------------------------------
# Field layout: (name, width). Order is the packed-struct order, MSB first.
# ---------------------------------------------------------------------------
FIELDS = [
    ("next", 12),
    ("seq", 4),
    ("cc", 5),
    ("cc_inv", 1),
    ("dest", 3),
    ("fn", 3),
    ("src", 3),
    ("a", 4),
    ("b", 4),
    ("cn", 2),
    ("d", 5),
    ("d_inv", 1),
    ("shf_dir", 2),
    ("shf_fill", 3),
    ("shf_sign", 1),
    ("cap_sel", 2),
    ("pc_inc", 1),
    ("pc_load", 1),
    ("ir_load", 1),
    ("ir_ind", 1),
    ("mb_load", 1),
    ("ma_load", 1),
    ("ov_upd", 1),
    ("ov_clr", 1),
    ("halt", 1),
    ("skip", 1),
    ("mem_op", 2),
    ("mem_wdata", 1),
    ("io_strobe", 1),
    ("io_load", 1),
    ("sbs_vec", 1),
    ("flag_we", 1),
    ("flag_set", 1),
    ("flag_sel", 3),
    ("flag_dyn", 1),
    ("nfc_load", 1),
    ("nfc_dec", 1),
    ("illegal", 1),
    ("core", 1),
    ("retire", 1),
    ("trace", 1),
    ("seq_disp", 2),
    ("imm", 18),
]

WIDTH = sum(width for _, width in FIELDS)

# ---------------------------------------------------------------------------
# Enumerations (names must match src/pdp1_pkg.sv where the RTL decodes them).
# ---------------------------------------------------------------------------
SEQ = {
    "JZ": 0, "CJS": 1, "JMAP": 2, "CJP": 3,
    "PUSH": 4, "JSRP": 5, "CJV": 6, "JRP": 7,
    "RFCT": 8, "RPCT": 9, "CRTN": 10, "CJPP": 11,
    "LDCT": 12, "LOOP": 13, "CONT": 14, "TWB": 15,
}

CC = {
    "FALSE": 0, "TRUE": 1, "IR_IND": 2, "AC_ZERO": 3,
    "AC_SIGN": 4, "IO_SIGN": 5, "IO_LSB": 6, "OV": 7,
    "NFC_ZERO": 8, "EAC": 9, "IO_READY": 10, "SBS_REQ": 11,
    "IR_A7": 12, "IR_A8": 13, "IR_A9": 14, "IR_A10": 15,
    "IR_A11": 16, "IR_A3": 17, "IR_A6": 18, "SKIP_ANY": 19,
    "IR_A12": 30,
    "IR_A2_0": 20, "IR_A5_3": 21, "PF_ALL_ZERO": 22, "SS_ALL_ZERO": 23,
    "SBS_ACTIVE": 24, "IR_A5": 25, "IO_ZERO": 26, "MEM_IDLE": 27,
    "HALTED": 28, "RESULT_ZERO": 29, "ALWAYS": 31,
}

FN = {"ADD": 0, "SUBR": 1, "SUB": 2, "OR": 3, "AND": 4, "ANDNOT": 5, "XOR": 6, "XNOR": 7}
# Names are from the Am2901 viewpoint: R and S are selected by `src`.
# The assembler's `fn` token writes the manufacturer's I5..I3 field.
SRC = {  # I2..I0
    "AQ": 0, "AB": 1, "ZQ": 2, "ZB": 3, "ZA": 4, "DA": 5, "DQ": 6, "DZ": 7,
}

REG = {"AC": 0, "IO": 1, "TMP0": 2, "TMP1": 3, "ZERO": 4}

D = {
    "ZERO": 0, "ONE": 1, "ONES": 2, "MB": 3, "MEM": 4, "ADDR": 5,
    "ADDR1": 6, "PC": 7, "MA": 8, "TW": 9, "SS": 10, "Y": 11,
    "SHF": 12, "IMM": 13, "STATUS": 14, "DEVDATA": 15,
}

SHF = {"NONE": 0, "LEFT": 1, "RIGHT": 2}
FILL = {"ZERO": 0, "SIGN": 1, "EXT_A": 2, "EXT_B": 3, "ROT": 4}
DISP = {"UC": 0, "OP": 1, "DEV": 2, "OPX": 3}
MEM = {"NONE": 0, "READ": 1, "WRITE": 2}


@dataclass
class Word:
    address: int
    label: str
    text: str
    values: dict[str, int] = field(default_factory=dict)

    def bits(self) -> int:
        out = 0
        for name, width in FIELDS:
            value = self.values.get(name, 0)
            if value < 0 or value >= (1 << width):
                raise ValueError(
                    f"address 0x{self.address:03x}: field {name}={value} "
                    f"does not fit {width} bits ({self.text!r})")
            out = (out << width) | value
        return out


def parse_number(text: str) -> int:
    text = text.strip().lower()
    if text.startswith("0o"):
        return int(text, 8)
    if text.startswith("0x"):
        return int(text, 16)
    if text.startswith("0b"):
        return int(text, 2)
    return int(text, 10)


def split_tokens(line: str) -> list[str]:
    line = line.split(";", 1)[0].strip()
    if not line:
        return []
    return [tok.strip() for tok in re.split(r"[,\s]+", line) if tok.strip()]


def assemble(source: str) -> tuple[list[Word], dict[str, int], str]:
    address = 0
    labels: dict[str, int] = {}
    words: list[Word] = []
    fill_text = "CONT"
    # First pass: labels and addresses; second pass: encode. Both need the same
    # parse, so keep the raw lines and resolve labels afterwards.
    raw: list[tuple[int, str, str]] = []   # (address, label, text)
    pending_labels: list[tuple[str, int]] = []

    def flush_labels(at: int) -> None:
        for name, _ in pending_labels:
            if name in labels:
                raise ValueError(f"duplicate label {name}")
            labels[name] = at
        pending_labels.clear()

    for lineno, raw_line in enumerate(source.splitlines(), 1):
        line = raw_line.split(";", 1)[0].strip()
        if not line:
            continue
        if line.startswith("@"):
            directive, _, rest = line.partition(" ")
            if directive == "@org":
                flush_labels(address)
                address = parse_number(rest)
            elif directive == "@fill":
                fill_text = rest.strip()
            else:
                raise ValueError(f"line {lineno}: unknown directive {directive}")
            continue
        label = ""
        if line.endswith(":"):
            label = line[:-1].strip()
            line = ""
        elif ":" in line.split("=", 1)[0]:
            head, _, tail = line.partition(":")
            label = head.strip()
            line = tail.strip()
        if label:
            pending_labels.append((label, address))
        if line:
            flush_labels(address)
            raw.append((address, label, line))
            words.append(Word(address, label, line))
            address += 1
        elif pending_labels:
            # A label may sit alone on a line; flush it at the next content.
            pass
    flush_labels(address)
    if address >= 4096:
        raise ValueError(f"microcode too large: {address} words")

    for word in words:
        tokens = split_tokens(word.text)
        values: dict[str, int] = {}
        for token in tokens:
            if "=" not in token:
                key, value = token, "1"
            else:
                key, value = token.split("=", 1)
            key = key.strip().lower()
            value = value.strip()
            if key == "seq":
                values["seq"] = SEQ[value.upper()]
            elif key == "cc":
                values["cc"] = CC[value.upper()]
            elif key == "cc_inv":
                values["cc_inv"] = 1
            elif key == "next":
                if value.isdigit() or value.lower().startswith(("0x", "0o")):
                    values["next"] = parse_number(value)
                else:
                    if value not in labels:
                        raise ValueError(f"0x{word.address:03x}: unknown label {value}")
                    values["next"] = labels[value]
            elif key == "dest":
                values["dest"] = parse_number(value)
            elif key == "fn":
                values["fn"] = FN[value.upper()]
            elif key == "src":
                # Manufacturer I2..I0 operand select.
                values["src"] = SRC[value.upper()]
            elif key == "a":
                values["a"] = REG[value.upper()]
            elif key == "b":
                values["b"] = REG[value.upper()]
            elif key == "cn":
                values["cn"] = parse_number(value)
            elif key == "d":
                values["d"] = D[value.upper()]
            elif key == "d_inv":
                values["d_inv"] = 1
            elif key == "shf":
                values["shf_dir"] = SHF[value.upper()]
            elif key == "fill":
                values["shf_fill"] = FILL[value.upper()]
            elif key == "cap":
                values["cap_sel"] = {"NONE": 0, "A": 1, "B": 2}[value.upper()]
            elif key == "ext_cap":
                values["cap_sel"] = 1
            elif key == "shf_sign":
                values["shf_sign"] = 1
            elif key == "flag_clr":
                values["flag_set"] = 0
            elif key == "pc_inc":
                values["pc_inc"] = 1
            elif key == "pc_load":
                values["pc_load"] = 1
            elif key == "ir_load":
                values["ir_load"] = 1
            elif key == "ir_ind":
                values["ir_ind"] = 1
            elif key == "mb_load":
                values["mb_load"] = 1
            elif key == "ma_load":
                values["ma_load"] = 1
            elif key == "ov_upd":
                values["ov_upd"] = 1
            elif key == "ov_clr":
                values["ov_clr"] = 1
            elif key == "halt":
                values["halt"] = 1
            elif key == "skip":
                values["skip"] = 1
            elif key == "mem":
                values["mem_op"] = MEM[value.upper()]
            elif key == "wdata":
                values["mem_wdata"] = 1 if value.upper() == "F" else 0
            elif key == "io_strobe":
                values["io_strobe"] = 1
            elif key == "io_load":
                values["io_load"] = 1
            elif key == "sbs_vec":
                values["sbs_vec"] = 1
            elif key == "flag_we":
                values["flag_we"] = 1
            elif key == "flag_set":
                values["flag_set"] = 1
            elif key == "flag_sel":
                values["flag_sel"] = parse_number(value)
            elif key == "flag_dyn":
                values["flag_dyn"] = 1
            elif key == "nfc_load":
                values["nfc_load"] = 1
            elif key == "nfc_dec":
                values["nfc_dec"] = 1
            elif key == "illegal":
                values["illegal"] = 1
            elif key == "core":
                values["core"] = 1
            elif key == "retire":
                values["retire"] = 1
            elif key == "trace":
                values["trace"] = 1
            elif key == "disp":
                values["seq_disp"] = DISP[value.upper()]
            elif key == "imm":
                values["imm"] = parse_number(value)
            elif key == "nop":
                pass
            else:
                raise ValueError(f"0x{word.address:03x}: unknown token {token!r}")
        # Sequential fall-through and no register write unless asked for.
        values.setdefault("seq", SEQ["CONT"])
        values.setdefault("dest", 1)
        values.setdefault("cc", CC["FALSE"])
        word.values = values
    fill = {}
    # Fill word: a plain CONT with no side effects.
    fill["seq"] = SEQ.get(fill_text.upper(), 14) if fill_text.upper() in SEQ else 14
    fill_word = Word(0, "@fill", fill_text, fill)
    return words, labels, fill_word


def emit_sv(words: list[Word], fill: Word, size: int) -> str:
    layout = "\n".join(
        f"  logic [{width - 1}:0] {name};" for name, width in FIELDS)
    lines = [
        "`timescale 1ns/1ps",
        "// Generated by scripts/ucasm.py from pdp1_uc.uc. Do not edit by hand.",
        f"// Control word: {WIDTH} bits.",
        "`ifndef PDP1_UC_SV",
        "`define PDP1_UC_SV",
        "",
        "package pdp1_uc_pkg;",
        "  typedef struct packed {",
        layout,
        "  } pdp1_uc_t;",
        "endpackage",
        "",
        "module pdp1_uc (",
        "  input  logic [11:0] addr_i,",
        "  output pdp1_uc_pkg::pdp1_uc_t word_o",
        ");",
        "  always_comb begin",
        f"    word_o = {WIDTH}'h{fill.bits():0{(WIDTH + 3) // 4}x};",
        "    case (addr_i)",
    ]
    for word in sorted(words, key=lambda w: w.address):
        lines.append(
            f"      12'h{word.address:03x}: word_o = {WIDTH}'h{word.bits():0{(WIDTH + 3) // 4}x};"
            f"  // {word.label or ''} {word.text}")
    lines += [
        "      default: ;",
        "    endcase",
        "  end",
        "endmodule",
        "",
        "`endif",
        "",
    ]
    return "\n".join(lines)


def emit_listing(words: list[Word]) -> str:
    lines = []
    for word in sorted(words, key=lambda w: w.address):
        lines.append(f"{word.address:03x}  {word.bits():0{(WIDTH + 3) // 4}x}  "
                     f"{word.label:<16} {word.text}")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    with open(argv[1], "r", encoding="utf-8") as handle:
        source = handle.read()
    words, labels, fill = assemble(source)
    text = emit_sv(words, fill, 4096)
    with open(argv[2], "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    listing = argv[2].replace(".sv", ".lst")
    with open(listing, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(emit_listing(words))
    used = len(words)
    print(f"assembled {used} microinstructions, {len(labels)} labels, "
          f"{WIDTH} bits/word -> {argv[2]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
