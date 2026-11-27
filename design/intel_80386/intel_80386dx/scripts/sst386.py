#!/usr/bin/env python3
"""Reader for the pinned SingleStepTests/80386 real-mode MOO captures.

The captures were recorded from a physical Intel 80386EX (KU80C386EX33) by
the ArduinoX86 board; see the upstream README at the pinned revision. This
module parses the chunked MOO format (MOO header, META, TEST records with
NAME/BYTS/INIT/FINA/CYCL/HASH/EXCP chunks; 32-bit state in RG32/EA32 chunks)
and resolves each test's final register file and memory.
"""

from __future__ import annotations

import csv
import gzip
import hashlib
import os
import pathlib
import urllib.request

REVISION = "459d49fbe6280e9ed46fee887b58dacd9cb880ab"
BASE_URL = f"https://raw.githubusercontent.com/SingleStepTests/80386/{REVISION}/"
SUBSET = "v1_ex_real_mode"

# RG32 register order (bit k of the RG32 mask).
REG_ORDER = (
    "cr0", "cr3", "eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp",
    "cs", "ds", "es", "fs", "gs", "ss", "eip", "eflags", "dr6", "dr7",
)
CYCLE_RECORD = 15
IO_READ_STATUS = 2


def _u32(data: bytes, offset: int) -> int:
    return int.from_bytes(data[offset:offset + 4], "little")


def _chunks(data: bytes, start: int, end: int):
    cursor = start
    while cursor < end:
        if end - cursor < 8:
            raise ValueError("truncated chunk header")
        tag = data[cursor:cursor + 4].decode("ascii")
        length = _u32(data, cursor + 4)
        payload = cursor + 8
        if payload + length > end:
            raise ValueError(f"chunk {tag!r} overruns its parent")
        yield tag, payload, payload + length
        cursor = payload + length


def _regs(data: bytes, start: int, end: int) -> dict:
    mask = _u32(data, start)
    if mask >> len(REG_ORDER):
        raise ValueError("RG32 mask uses undefined register bits")
    if end - start != 4 + 4 * bin(mask).count("1"):
        raise ValueError("RG32 mask and value count disagree")
    regs, cursor = {}, start + 4
    for bit, name in enumerate(REG_ORDER):
        if mask >> bit & 1:
            regs[name] = _u32(data, cursor)
            cursor += 4
    return regs


def _ram(data: bytes, start: int, end: int) -> list:
    count = _u32(data, start)
    if end - start != 4 + 5 * count:
        raise ValueError("RAM entry count does not match payload")
    return [(_u32(data, start + 4 + 5 * k), data[start + 8 + 5 * k]) for k in range(count)]


def _state(data: bytes, start: int, end: int) -> dict:
    state = {"regs": {}, "ram": [], "descriptors": False}
    for tag, a, b in _chunks(data, start, end):
        if tag == "RG32":
            state["regs"] = _regs(data, a, b)
        elif tag == "RAM ":
            state["ram"] = _ram(data, a, b)
        elif tag in ("RG16", "REGS"):
            raise ValueError("16-bit register chunk in a 386 capture")
        elif tag in ("DS32", "DESC"):
            state["descriptors"] = True
    return state


def _io_reads(data: bytes, start: int, end: int) -> list:
    """Data-bus words sampled at T2 of each I/O read cycle."""
    count = _u32(data, start)
    if end - start != 4 + CYCLE_RECORD * count:
        raise ValueError("cycle count does not match 15-byte records")
    words, last_t1_io = [], False
    for k in range(count):
        rec = data[start + 4 + CYCLE_RECORD * k:start + 4 + CYCLE_RECORD * (k + 1)]
        status, tstate = rec[11], rec[12]
        if tstate == 1:
            last_t1_io = status == IO_READ_STATUS
        elif tstate == 2 and last_t1_io and status == IO_READ_STATUS:
            words.append(int.from_bytes(rec[9:11], "little"))
    return words


def parse(data: bytes):
    """Yield test dictionaries from a decompressed MOO file."""
    if data[:4] != b"MOO ":
        raise ValueError("not a MOO file")
    for tag, a, b in _chunks(data, 0, len(data)):
        if tag != "TEST":
            continue
        test = {"idx": _u32(data, a), "exception": None, "io_reads": []}
        for t2, c, d in _chunks(data, a + 4, b):
            if t2 == "NAME":
                test["name"] = data[c + 4:d].decode("ascii")
            elif t2 == "BYTS":
                test["bytes"] = list(data[c + 4:d])
            elif t2 == "INIT":
                test["initial"] = _state(data, c, d)
            elif t2 == "FINA":
                test["final"] = _state(data, c, d)
            elif t2 == "HASH":
                test["hash"] = data[c:d].hex()
            elif t2 == "EXCP":
                test["exception"] = {"number": data[c], "flag_address": _u32(data, c + 1)}
            elif t2 == "CYCL":
                test["io_reads"] = _io_reads(data, c, d)
        for key in ("name", "bytes", "initial", "final", "hash"):
            if key not in test:
                raise ValueError(f"test {test['idx']} lacks {key}")
        yield test


def capture_dir() -> pathlib.Path:
    """Directory holding the capture files: a local mirror or the cache."""
    mirror = os.environ.get("SST386_DIR")
    if mirror:
        return pathlib.Path(mirror) / SUBSET
    here = pathlib.Path(__file__).resolve().parent.parent
    return here / "work" / "sst386" / REVISION / SUBSET


def load_file(stem: str) -> tuple[bytes, dict]:
    """Return decompressed bytes and provenance for one capture file."""
    path = capture_dir() / f"{stem}.MOO.gz"
    url = f"{BASE_URL}{SUBSET}/{stem}.MOO.gz"
    if not path.exists():
        if os.environ.get("SST386_DIR"):
            raise FileNotFoundError(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(url, timeout=120) as response:
            raw = response.read()
        tmp = path.with_suffix(".part")
        tmp.write_bytes(raw)
        tmp.replace(path)
    raw = path.read_bytes()
    return gzip.decompress(raw), {
        "file": f"{SUBSET}/{stem}.MOO.gz", "url": url,
        "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
    }


def load_metadata() -> dict:
    """Per-opcode metadata (f_umask flag compare masks) from 80386.csv."""
    path = capture_dir().parent / "80386.csv"
    if not path.exists():
        if os.environ.get("SST386_DIR"):
            raise FileNotFoundError(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(BASE_URL + "80386.csv", timeout=60) as response:
            path.write_bytes(response.read())
    rows = {}
    with path.open(newline="") as handle:
        for row in csv.DictReader(handle):
            key = row["op"] + (("." + row["ex"]) if row["ex"] else "")
            rows[key] = row
    return rows


def load_revocations() -> set:
    path = capture_dir().parent / "revocation_list.txt"
    if not path.exists():
        if os.environ.get("SST386_DIR"):
            raise FileNotFoundError(path)
        with urllib.request.urlopen(BASE_URL + "revocation_list.txt", timeout=60) as response:
            path.write_bytes(response.read())
    return {line.strip().lower() for line in path.read_text().splitlines()
            if line.strip() and not line.startswith("#")}


def base_opcode(stem: str) -> str:
    """Strip 66/67 size prefixes from a file stem to find its CSV row."""
    while stem[:2] in ("66", "67") and len(stem) > 2:
        stem = stem[2:]
    return stem


def flag_compare_mask(row: dict | None) -> int:
    """EFLAGS bits to compare: upper 16 always, lower 16 per f_umask."""
    low = 0xFFFF
    if row and row.get("f_umask"):
        low = int(row["f_umask"], 16)
    return 0xFFFF0000 | low
