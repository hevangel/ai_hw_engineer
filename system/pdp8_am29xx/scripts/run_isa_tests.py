"""PDP-8 ISA agreement tests: RTL against the independent reference model.

Each test builds a program image, runs the independent ISS (scripts/pdp8_ref.py)
to obtain the expected architectural trace, runs the Verilator model and
compares the per-instruction traces (PC, AC, LINK) exactly.

Tests
  opr_group1      every group-one encoding from two starting states
  opr_group2      every group-two encoding without HLT, plus a HLT run
  addressing      direct/current-page/indirect/auto-index directed programs
  control         JMS/JMP direct and indirect, ISZ skip, return-cell behaviour
  random          straight-line pseudo-random programs in a fixed layout
  console         printer, keyboard echo, paper-tape read (transcript checks)

Usage
  python scripts/run_isa_tests.py --binary work/obj/Vtb_top [--only NAME]
                                  [--seeds N] [--list]
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import pdp8_ref  # noqa: E402

WORD = 0o7777
HERE = pathlib.Path(__file__).resolve().parent
WORK = HERE.parent / "work" / "isa"


# --------------------------------------------------------------------- helpers
def memref(op: int, addr: int, page: bool, indirect: bool) -> int:
    return ((op & 7) << 9) | (0o200 if page else 0) | (0o400 if indirect else 0) | (addr & 0o177)


def clamp(word: int) -> int:
    return word & WORD


def write_image(path: pathlib.Path, words: dict[int, int]) -> None:
    top = max(words) if words else 0
    lines = []
    for address in range(top + 1):
        lines.append(f"{words[address]:03x}" if address in words else "xxx")
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def run_verilator(binary: str, image: pathlib.Path, trace: pathlib.Path,
                  extra: list[str] | None = None) -> str:
    args = [binary, f"+prog={image}", f"+trace={trace}", "+maxcyc=400000"]
    if extra:
        args.extend(extra)
    result = subprocess.run(args, capture_output=True, text=True, timeout=600)
    return result.stdout + result.stderr


def compare(name: str, expected: list[tuple[int, int, int]],
            actual: list[tuple[int, int, int]]) -> str | None:
    for index, (want, got) in enumerate(zip(expected, actual)):
        if want != got:
            return (f"{name}: instruction {index} mismatch: "
                    f"expected pc={want[0]:04o} ac={want[1]:04o} l={want[2]}, "
                    f"got pc={got[0]:04o} ac={got[1]:04o} l={got[2]}")
    if len(expected) != len(actual):
        return (f"{name}: trace length {len(actual)} != expected {len(expected)}; "
                f"first extra at {min(len(expected), len(actual))}")
    return None


def read_trace(path: pathlib.Path) -> list[tuple[int, int, int]]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        pc, ac, link = line.split()
        rows.append((int(pc), int(ac), int(link)))
    return rows


# ---------------------------------------------------------------------- tests
def test_opr_group1() -> tuple[dict[int, int], int, dict]:
    """Every group-one encoding from two AC/LINK states."""
    code = 0o200
    words: dict[int, int] = {}
    words[0o020] = 0o5252
    words[0o021] = 0o7777
    setup = [
        [0o7200, 0o1020, 0o7120],   # CLA, TAD C1, STL  -> AC=5252, L=1
        [0o7200, 0o1021, 0o7000],   # CLA, TAD C2, NOP  -> AC=7777, L=0
    ]
    for encoding in range(0o7000, 0o7400):
        if (encoding & 0o014) == 0o014:
            continue                      # both rotate bits: undefined, excluded
        for state in setup:
            for word in state:
                words[code] = word
                code += 1
            words[code] = encoding
            code += 1
    for address in range(code, 0o400):
        words[address] = 0o7000           # NOP padding
    words[code] = 0o7402                  # HLT
    return words, 0o200, {"kind": "isa"}


def test_opr_group2() -> tuple[dict[int, int], int, dict]:
    """Every group-two encoding except HLT, from two states, with a NOP landing pad."""
    code = 0o200
    words: dict[int, int] = {}
    words[0o020] = 0o5252
    words[0o021] = 0o0000
    words[0o022] = 0o4001
    states = [
        [0o7200, 0o1020, 0o7120],   # AC=5252, L=1
        [0o7200, 0o1021, 0o7000],   # AC=0,    L=0
        [0o7200, 0o1022, 0o7000],   # AC=4001, L=0
    ]
    for encoding in range(0o7400, 0o7777, 2):
        if encoding & 0o002:
            continue                      # HLT
        for state in states:
            for word in state:
                words[code] = word
                code += 1
            words[code] = encoding
            code += 1
            words[code] = 0o7000          # landing pad for the skip
            code += 1
    for address in range(code, 0o400):
        words[address] = 0o7000
    words[code] = 0o7402
    return words, 0o200, {"kind": "isa"}


def test_addressing() -> tuple[dict[int, int], int, dict]:
    """Directed addressing modes, including the page-boundary case."""
    words: dict[int, int] = {}
    # Data
    words[0o040] = 0o1111
    words[0o041] = 0o2222
    words[0o010] = 0o040          # auto-index pointer to 0041
    words[0o011] = 0o044
    words[0o012] = 0o000
    words[0o030] = 0o045          # indirect pointer, page zero
    words[0o045] = 0o3333
    words[0o046] = 0o4444
    words[0o250] = 0o5555         # page one data
    words[0o251] = 0o6666
    words[0o270] = 0o030          # page-one indirect pointer
    words[0o277] = 0o7777         # last word of page one

    code = 0o200
    program = [
        # direct page zero
        0o7200, memref(1, 0o040, False, False),     # TAD 040
        0o3020,                                      # DCA 020
        # direct current page
        0o7200, memref(1, 0o250, True, False),      # TAD 250 (current page)
        0o3020,
        # indirect page zero
        0o7200, memref(1, 0o030, False, True),      # TAD I 030 -> 045
        0o3020,
        # indirect current page
        0o7200, memref(1, 0o270, True, True),       # TAD I 270 -> 030 -> 045
        0o3020,
        # auto-index through pointer 0010: value 0040 becomes 0041
        0o7200, memref(1, 0o010, False, True),
        0o3020,
        # auto-index again: 0041 becomes 0042
        0o7200, memref(1, 0o010, False, True),
        0o3020,
        # auto-index through 0011
        0o7200, memref(1, 0o011, False, True),
        0o3020,
        # page-boundary: instruction at 0277 uses page one, not page two
        0o7000, 0o7000,
        # AND with zero
        0o7200, memref(0, 0o040, False, False),
        0o3020,
        # ISZ that does not reach zero
        0o7000,
        memref(2, 0o046, False, False),
        # ISZ that reaches zero: 7777 + 1 = 0
        0o7200, 0o1023,
        0o3024,
        memref(2, 0o024, False, False),
        0o7200, 0o1023,
    ]
    for word in program:
        words[code] = word
        code += 1

    # Put the page-boundary instruction exactly at 0277.
    boundary = 0o277
    words[boundary] = memref(1, 0o277, True, False)   # TAD 277 (self, 7777)
    words[boundary + 1] = 0o3021
    words[0o021] = 0o7777

    words[code] = 0o7402
    return words, 0o200, {"kind": "isa"}


def test_control() -> tuple[dict[int, int], int, dict]:
    """JMS/JMP direct and indirect, subroutine return, ISZ skip."""
    words: dict[int, int] = {}

    def op(opcode: int, address: int, indirect: bool = False) -> int:
        """Encode a memory reference to an absolute 12-bit address."""
        return memref(opcode, address & 0o177, bool(address & 0o200), indirect)

    # Page-zero data and pointers
    words[0o030] = 0o110            # indirect JMS pointer -> subroutine two
    words[0o031] = 0o230            # indirect JMP pointer -> continuation
    words[0o040] = 0o1234
    words[0o041] = 0o7777

    # Subroutine one at 0100: indirect return through its first word.
    words[0o100] = 0o000
    words[0o101] = 0o7200           # CLA
    words[0o102] = 0o7021           # CML
    words[0o103] = op(5, 0o100, True)

    # Subroutine two at 0110: increment and return.
    words[0o110] = 0o000
    words[0o111] = 0o7001           # IAC
    words[0o112] = op(5, 0o110, True)

    # Main program at 0200
    words[0o200] = 0o7200                      # CLA
    words[0o201] = op(4, 0o100)                # JMS 100
    words[0o202] = 0o7001                      # IAC after return
    words[0o203] = 0o3020                      # DCA 020
    words[0o204] = op(5, 0o210)                # JMP 210
    words[0o205] = 0o7001                      # skipped
    words[0o210] = 0o1040                      # TAD 040
    words[0o211] = op(4, 0o030, True)   # JMS I 030 -> 110
    words[0o212] = 0o7001                      # IAC
    words[0o213] = 0o3021                      # DCA 021
    words[0o214] = op(5, 0o031, True)   # JMP I 031 -> 230
    words[0o230] = 0o7001                      # IAC
    words[0o231] = 0o3022                      # DCA 022
    words[0o232] = 0o2020                      # ISZ 020
    words[0o233] = 0o2030                      # ISZ 030
    words[0o234] = 0o7402                      # HLT
    return words, 0o200, {"kind": "isa"}


def build_random(seed: int, length: int = 48) -> tuple[dict[int, int], int, dict]:
    """Straight-line random program over a fixed memory layout."""
    import random
    rng = random.Random(seed)
    words: dict[int, int] = {}
    # Page-zero data 0040-0077, auto-index 0010-0017, page-one data 0350-0377.
    for address in range(0o040, 0o100):
        words[address] = 0o7000
    for address in range(0o040, 0o050):
        words[address] = rng.randrange(0, 0o10000)
    for address in range(0o010, 0o020):
        words[address] = 0o040 + rng.randrange(0, 0o10)
    for address in range(0o350, 0o400):
        words[address] = rng.randrange(0, 0o10000)

    page0 = list(range(0o040, 0o050))
    page1 = list(range(0o350, 0o400))
    code = 0o200
    for _ in range(length):
        choice = rng.random()
        if choice < 0.55:
            op = rng.choice([0, 1, 2, 3])
            if rng.random() < 0.5:
                target = rng.choice(page0)
                page, indirect = False, rng.random() < 0.4
            else:
                target = rng.choice(page1)
                page, indirect = True, rng.random() < 0.4
            words[code] = memref(op, target, page, indirect)
        elif choice < 0.8:
            # group one, excluding the undefined double-rotate combinations
            encoding = rng.randrange(0o7000, 0o7400)
            if (encoding & 0o014) == 0o014:
                encoding &= ~0o010
            words[code] = encoding
        else:
            # group two without HLT
            encoding = rng.randrange(0o7400, 0o7777) & ~1
            encoding &= ~0o002
            words[code] = encoding
        code += 1
    words[code] = 0o7000
    code += 1
    words[code] = 0o7000
    code += 1
    words[code] = 0o7402
    return words, 0o200, {"kind": "isa"}


# ----------------------------------------------------------------- console I/O
def console_tests() -> list[tuple[str, dict[int, int], int, dict, bytes, bytes]]:
    """Programs whose result is the console transcript rather than a trace."""
    tests = []

    # Print "HI" then halt.  6000-0000 hex is not used: build words directly.
    def iot(device: int, pulse: int) -> int:
        return 0o6000 | ((device & 0o77) << 3) | (pulse & 7)

    words = {
        0o200: 0o7200,                 # CLA
        0o201: 0o1061,                 # TAD 061 ('H')
        0o202: iot(4, 1),              # TSF
        0o203: 0o5202,                 # JMP .-1
        0o204: iot(4, 6),              # TLS
        0o205: 0o7200,                 # CLA
        0o206: 0o1062,                 # TAD 062 ('I')
        0o207: iot(4, 1),
        0o210: 0o5207,
        0o211: iot(4, 6),
        0o212: 0o7402,
        0o061: ord("H"),
        0o062: ord("I"),
    }
    tests.append(("console_print", words, 0o200, {"kind": "io"}, b"HI", b""))

    # Keyboard echo: read one character with KSF/KRB and print it.
    words = {
        0o200: iot(3, 1),              # KSF
        0o201: 0o5200,                 # JMP .-1
        0o202: iot(3, 6),              # KRB
        0o203: 0o3020,                 # DCA 020
        0o204: 0o1020,                 # TAD 020
        0o205: iot(4, 1),              # TSF
        0o206: 0o5205,
        0o207: iot(4, 6),              # TLS
        0o210: 0o7402,
    }
    tests.append(("console_echo", words, 0o200, {"kind": "io", "kb": b"Z"}, b"Z", b""))

    # Paper-tape reader: load 4 bytes through RFC/RSF/RRB into memory, then
    # print them back.
    words = {
        0o200: 0o7000,                 # NOP
        0o201: iot(1, 4),              # RFC
        0o202: iot(1, 1),              # RSF
        0o203: 0o5202,                 # JMP .-1
        0o204: iot(1, 6),              # RFC + RRB
        0o205: 0o7000,
        0o206: iot(1, 1),
        0o207: 0o5206,
        0o210: iot(1, 6),
        0o211: 0o7000,
        0o212: 0o7402,
    }
    tests.append(("reader_fetch", words, 0o200, {"kind": "io", "ptr": b"AB"},
                  b"", b""))

    return tests


# ---------------------------------------------------------------------- runner
def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", default="work/obj/Vtb_top")
    parser.add_argument("--only", default=None)
    parser.add_argument("--seeds", type=int, default=24)
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    WORK.mkdir(parents=True, exist_ok=True)
    cases: list[tuple[str, dict[int, int], int, dict]] = []
    cases.append(("opr_group1", *test_opr_group1()))
    cases.append(("opr_group2", *test_opr_group2()))
    cases.append(("addressing", *test_addressing()))
    cases.append(("control", *test_control()))
    for seed in range(args.seeds):
        cases.append((f"random_{seed:03d}", *build_random(seed)))

    if args.list:
        for name, _, _, _ in cases:
            print(name)
        return 0

    failures = 0
    selected = [case for case in cases if args.only is None or args.only in case[0]]
    for name, words, start, options in selected:
        image = WORK / f"{name}.hex"
        write_image(image, words)
        expected, cpu = pdp8_ref.run_image(_memory(words), start)
        trace = WORK / f"{name}.trace"
        output = run_verilator(args.binary, image, trace,
                              [f"+start={start}", "+sw=0"])
        if "PASS" not in output:
            print(f"FAIL {name}: model did not stop\n{output}")
            failures += 1
            continue
        actual = read_trace(trace)
        problem = compare(name, expected, actual)
        if problem:
            print("FAIL " + problem)
            failures += 1
        else:
            print(f"PASS {name}: {len(expected)} instructions")

    # Console/paper-tape programs: compare the transcript and the halted state.
    for name, words, start, options, want_tty, want_ptp in console_tests():
        image = WORK / f"{name}.hex"
        write_image(image, words)
        tty_out = WORK / f"{name}.tty"
        ptp_out = WORK / f"{name}.ptp"
        extra = [f"+start={start}", "+sw=0", f"+tty={tty_out}", f"+ptp={ptp_out}"]
        ptr_path = WORK / f"{name}.ptr"
        kb_path = WORK / f"{name}.kb"
        if "ptr" in options:
            ptr_path.write_bytes(options["ptr"])
            extra.append(f"+ptr={ptr_path}")
        if "kb" in options:
            kb_path.write_bytes(options["kb"])
            extra.append(f"+kb={kb_path}")
        output = run_verilator(args.binary, image, WORK / f"{name}.trace", extra)
        got_tty = tty_out.read_bytes() if tty_out.exists() else b""
        got_ptp = ptp_out.read_bytes() if ptp_out.exists() else b""
        if "PASS" not in output or got_tty != want_tty or got_ptp != want_ptp:
            print(f"FAIL {name}: stop={('PASS' in output)} tty={got_tty!r} ptp={got_ptp!r}")
            failures += 1
        else:
            print(f"PASS {name}: tty={got_tty!r}")

    print(f"{len(selected) + len(console_tests()) - failures} passed, {failures} failed")
    return 1 if failures else 0


def _memory(words: dict[int, int]) -> dict[int, int]:
    return {address: value for address, value in words.items()}


if __name__ == "__main__":
    raise SystemExit(main())
