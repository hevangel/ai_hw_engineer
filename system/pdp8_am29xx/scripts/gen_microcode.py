"""Microassembler for the PDP-8 Am29xx control store.

Reads ``src/pdp8_microcode.asm`` and writes ``src/pdp8_ucode.sv`` plus a
listing.  Every microinstruction is a 72-bit word decoded by ``pdp8_cpu``:

    field     bits   meaning
    cc        3:0    Am2910 condition select
    seq       7:4    Am2910 instruction
    addr     19:8    Am2910 branch target
    alf      22:20   Am2901 ALU function (I3-I5)
    src      25:23   Am2901 operand source (I0-I2)
    ra       29:26   Am2901 A-port register
    rb       33:30   Am2901 B-port register
    dest     36:34   Am2901 destination control (I6-I8)
    dsel     39:37   external D-bus select
    cin      41:40   Am2901 carry-in select
    acmask   44:42   gate that enables the accumulator write
    lmask    47:45   gate that enables the link write
    ma_ld    48      MA <- address source
    ma_sel   49      MA address source (0 = Y, 1 = page/offset)
    pc_ld    50      PC <- Y
    mb_ld    51      MB <- data source
    mb_sel   52      MB data source (0 = memory read, 1 = Y)
    ir_ld    53      IR <- memory read
    mem_rd   54      core memory read strobe
    rdsel    56:55   read address (0 = Y, 1 = MA, 2 = page/offset)
    mem_wr   57      core memory write strobe
    wrmb     58      write data (0 = Y, 1 = MB)
    lop      61:59   link update
    halt     62      halt request
    ion      63      enable interrupts
    iof      64      disable interrupts
    iot_ph   66:65   console strobe phase (1 = strobe, 2 = data)
    retire   67      instruction-boundary marker
    pg_ld    68      latch the instruction page from PC
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

FIELDS = {
    # name: (low bit, width)
    "cc": (0, 4),
    "seq": (4, 4),
    "addr": (8, 12),
    "alf": (20, 3),
    "src": (23, 3),
    "ra": (26, 4),
    "rb": (30, 4),
    "dest": (34, 3),
    "dsel": (37, 3),
    "cin": (40, 2),
    "acmask": (42, 3),
    "lmask": (45, 3),
    "ma_ld": (48, 1),
    "ma_sel": (49, 1),
    "pc_ld": (50, 1),
    "mb_ld": (51, 1),
    "mb_sel": (52, 1),
    "ir_ld": (53, 1),
    "mem_rd": (54, 1),
    "rdsel": (55, 2),
    "mem_wr": (57, 1),
    "wrmb": (58, 1),
    "lop": (59, 3),
    "halt": (62, 1),
    "ion": (63, 1),
    "iof": (64, 1),
    "iot_ph": (65, 2),
    "retire": (67, 1),
    "pg_ld": (68, 1),
    "sh_ir": (69, 1),
    "clr_ack": (70, 1),
}

ENUMS = {
    "cc": {
        "al": 0, "ir11": 1, "ir10": 2, "ir9": 3, "ir8": 4, "zero": 5,
        "l": 6, "g2": 7, "irq": 8, "ir1": 9, "ir0": 11, "clr": 10,
        "ir2": 12, "ai": 13, "iskip": 14, "go": 15,
    },
    "seq": {
        "jz": 0, "cjs": 1, "jmap": 2, "cjp": 3, "push": 4, "jrp": 5,
        "cjpp": 6, "cjpc": 7, "rfct": 8, "rpct": 9, "rtn": 10, "cjpp2": 11,
        "ldct": 12, "loop": 13, "cont": 14, "twb": 15,
    },
    "alf": {
        "add": 0, "subr": 1, "subs": 2, "or": 3, "and": 4, "andn": 5,
        "xor": 6, "xnor": 7,
    },
    "src": {"rq": 0, "rab": 1, "rq0": 2, "rb": 3, "a": 4, "da": 5, "dq": 6, "d": 7},
    "dest": {"q": 0, "none": 1, "rb": 2, "qrb": 3, "shr": 4, "shrq": 5, "shl": 6, "shlq": 7},
    "dsel": {"zero": 0, "mb": 1, "ma": 2, "pc": 3, "sr": 4, "one": 5, "iot": 6, "ff": 7},
    "cin": {"0": 0, "l": 1, "1": 2},
    "acmask": {"al": 0, "ir8": 1, "ir6": 2, "ir5": 3, "ir4": 4, "ir0": 5, "rot": 6, "ir2": 7},
    "lmask": {"al": 0, "ir8": 1, "ir6": 2, "ir5": 3, "ir4": 4, "ir0": 5, "rot": 6, "ir2": 7},
    "rdsel": {"y": 0, "ma": 1, "ea": 2},
    "lop": {"none": 0, "carry": 1, "xor": 2, "clr": 3, "set": 4, "cml": 5, "shift": 6},
    "iot_ph": {"off": 0, "strobe": 1, "data": 2},
}

# Registers in the three-slice Am2901 file.
REGS = {"ac": 0, "tmp": 1, "tmp2": 2, "tmp3": 3}

DEFAULT = {"seq": "cont"}


class AsmError(Exception):
    pass


def parse_line(line: str, lineno: int):
    """Return (label, list of (key, value)) for one source line."""
    text = line.split(";", 1)[0].strip()
    if not text:
        return None, []
    label = None
    if text.startswith("."):
        raise AsmError(f"line {lineno}: unknown directive {text}")
    if ":" in text.split()[0]:
        label, _, text = text.partition(":")
        label = label.strip()
        text = text.strip()
    tokens = text.replace(", ", ",").split()
    return label, tokens


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default="src/pdp8_microcode.asm")
    ap.add_argument("--out", default="src/pdp8_ucode.sv")
    ap.add_argument("--listing", default="work/ucode.lst")
    args = ap.parse_args()

    lines = pathlib.Path(args.source).read_text(encoding="utf-8").splitlines()

    words: list[dict] = []
    labels: dict[str, int] = {}
    for lineno, line in enumerate(lines, 1):
        try:
            label, tokens = parse_line(line, lineno)
        except AsmError as exc:
            print(exc, file=sys.stderr)
            return 1
        if label:
            if label in labels:
                print(f"line {lineno}: duplicate label {label}", file=sys.stderr)
                return 1
            labels[label] = len(words)
        if not tokens:
            continue
        word = dict(DEFAULT)
        index = 0
        while index < len(tokens):
            token = tokens[index]
            index += 1
            if token in ("cjp", "cjpp", "cjs"):
                if index >= len(tokens):
                    print(f"line {lineno}: {token} needs cc,target", file=sys.stderr)
                    return 1
                operands = tokens[index].split(",")
                index += 1
                if len(operands) == 1:
                    cond, target = "al", operands[0]
                else:
                    cond, target = operands[0], operands[1]
                word["seq"] = token
                word["cc"] = cond
                word["addr"] = target
                continue
            if token in ("jmp", "loop"):
                if index >= len(tokens):
                    print(f"line {lineno}: {token} needs a target", file=sys.stderr)
                    return 1
                word["seq"] = "cjp" if token == "jmp" else "loop"
                word["cc"] = "al"
                word["addr"] = tokens[index]
                index += 1
                continue
            if token == "rtn":
                word["seq"] = "rtn"
                cond = "al"
                if index < len(tokens) and tokens[index] in ENUMS["cc"]:
                    cond = tokens[index]
                    index += 1
                word["cc"] = cond
                continue
            if "=" in token:
                key, _, value = token.partition("=")
                if key in FIELDS:
                    if key in ENUMS and value not in ENUMS[key]:
                        print(f"line {lineno}: bad {key} value {value!r}", file=sys.stderr)
                        return 1
                    if key in ("ra", "rb") and value not in REGS:
                        print(f"line {lineno}: bad register {value!r}", file=sys.stderr)
                        return 1
                    word[key] = value
                elif key == "flag":
                    pass
                else:
                    print(f"line {lineno}: unknown field {key!r}", file=sys.stderr)
                    return 1
            elif token in FIELDS:
                word[token] = 1
            else:
                print(f"line {lineno}: unknown token {token!r}", file=sys.stderr)
                return 1
        words.append({"line": lineno, "src": line.strip(), "fields": word})

    encoded: list[int] = []
    for index, entry in enumerate(words):
        value = 0
        for key, (low, width) in FIELDS.items():
            raw = entry["fields"].get(key)
            if raw is None:
                num = 0
            elif isinstance(raw, int):
                num = raw
            elif key in ENUMS:
                num = ENUMS[key][raw]
            elif key in ("ra", "rb"):
                num = REGS[raw]
            elif key == "addr":
                if raw not in labels:
                    print(f"line {entry['line']}: unknown label {raw!r}", file=sys.stderr)
                    return 1
                num = labels[raw]
            else:
                num = int(raw, 0)
            if num >= (1 << width):
                print(f"line {entry['line']}: {key} value {num} does not fit", file=sys.stderr)
                return 1
            value |= num << low
        encoded.append(value)

    if len(encoded) > 4096:
        print("microcode exceeds the 4096-word sequencer address space", file=sys.stderr)
        return 1

    out = pathlib.Path(args.out)
    body = []
    for index, value in enumerate(encoded):
        body.append(f"      12'o{index:04o}: ucode_o = 72'h{value:018x};")
    text = f"""// Generated by scripts/gen_microcode.py from {pathlib.Path(args.source).name}.
// Do not edit by hand; edit the microcode source and regenerate.
`timescale 1ns/1ps
module pdp8_ucode (
    input  logic [11:0] addr_i,
    output logic [71:0] ucode_o
);
  always_comb begin
    ucode_o = 72'h{encoded[0]:018x};
    case (addr_i)
{chr(10).join(body)}
      default: ucode_o = 72'h{encoded[0]:018x};
    endcase
  end
endmodule
"""
    out.write_text(text, encoding="utf-8", newline="\n")

    listing = pathlib.Path(args.listing)
    listing.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    reverse = {}
    for name, addr in labels.items():
        reverse.setdefault(addr, []).append(name)
    for index, entry in enumerate(words):
        tags = ",".join(reverse.get(index, []))
        rows.append(f"{index:04o} {encoded[index]:018x} {tags:<20} {entry['src']}")
    listing.write_text("\n".join(rows) + "\n", encoding="utf-8", newline="\n")

    pathlib.Path("work/ucode_labels.json").write_text(
        json.dumps({"labels": labels, "words": len(encoded)}, indent=1), encoding="utf-8"
    )
    print(f"assembled {len(encoded)} microinstructions, {len(labels)} labels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
