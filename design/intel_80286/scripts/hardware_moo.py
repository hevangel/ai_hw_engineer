#!/usr/bin/env python3
"""Strict functional-state reader for the pinned 80286 MOO test files.

The chunk layout follows the SingleStepTests/80286 converter at revision
37c73caf53dcd22d3dd369ff09305d13d117a4fe and the MOO format's documented
little-endian chunk framing.  Cycle records are bounds-checked but omitted
from the returned object; this module does not validate timing behavior.
"""

from __future__ import annotations


REG_ORDER = (
    "ax", "bx", "cx", "dx", "cs", "ss", "ds", "es",
    "sp", "bp", "si", "di", "ip", "flags",
)
_REG_MASK = (1 << len(REG_ORDER)) - 1
_MOO_HEADER_MIN_SIZE = 12
_MOO_MAJOR_VERSION = 1
_MOO_MAX_MINOR_VERSION = 1
_MAX_RAM_ADDRESS = (1 << 24) - 1
_CYCLE_RECORD_SIZE = 15
_REQUIRED_TEST_CHUNKS = {"NAME", "BYTS", "INIT", "FINA", "HASH"}


def _error(context: str, message: str) -> ValueError:
    return ValueError(f"{context}: {message}")


def _chunk(data: bytes, offset: int, end: int, context: str):
    """Read one bounded MOO chunk and return (tag, data_start, data_end)."""
    if offset < 0 or end < offset or end > len(data):
        raise _error(context, "invalid enclosing boundary")
    if end - offset < 8:
        raise _error(context, "truncated chunk header")

    raw_tag = data[offset:offset + 4]
    if any(byte < 0x20 or byte > 0x7E for byte in raw_tag):
        raise _error(context, f"invalid chunk identifier {raw_tag!r}")
    tag = raw_tag.decode("ascii")
    length = int.from_bytes(data[offset + 4:offset + 8], "little")
    payload_start = offset + 8
    if length > end - payload_start:
        raise _error(context, f"{tag!r} payload extends beyond its enclosing chunk")
    return tag, payload_start, payload_start + length


def _u16(data: bytes, offset: int, end: int, context: str) -> int:
    if offset < 0 or end - offset < 2:
        raise _error(context, "truncated 16-bit value")
    return int.from_bytes(data[offset:offset + 2], "little")


def _u32(data: bytes, offset: int, end: int, context: str) -> int:
    if offset < 0 or end - offset < 4:
        raise _error(context, "truncated 32-bit value")
    return int.from_bytes(data[offset:offset + 4], "little")


def _parse_regs(data: bytes, start: int, end: int, context: str) -> dict:
    mask = _u16(data, start, end, context)
    if mask & ~_REG_MASK:
        raise _error(context, "register mask uses undefined register bits")
    expected_size = 2 + 2 * mask.bit_count()
    if end - start != expected_size:
        raise _error(context, "register mask and value count disagree")

    regs = {}
    cursor = start + 2
    for bit, name in enumerate(REG_ORDER):
        if mask & (1 << bit):
            regs[name] = _u16(data, cursor, end, context)
            cursor += 2
    return regs


def _parse_ram(data: bytes, start: int, end: int, context: str) -> list:
    count = _u32(data, start, end, context)
    if count != (end - start - 4) // 5 or (end - start - 4) % 5:
        raise _error(context, "RAM entry count does not match payload length")

    ram = []
    seen_addresses = set()
    cursor = start + 4
    for _ in range(count):
        address = _u32(data, cursor, end, context)
        value = data[cursor + 4]
        if address > _MAX_RAM_ADDRESS:
            raise _error(context, f"RAM address 0x{address:X} exceeds 24-bit physical space")
        if address in seen_addresses:
            raise _error(context, f"duplicate RAM address 0x{address:X}")
        seen_addresses.add(address)
        ram.append([address, value])
        cursor += 5
    return ram


def _parse_queue(data: bytes, start: int, end: int, context: str) -> list:
    count = _u32(data, start, end, context)
    if count != end - start - 4:
        raise _error(context, "queue byte count does not match payload length")
    return list(data[start + 4:end])


def _parse_state(data: bytes, start: int, end: int, context: str) -> dict:
    state = {"regs": {}, "ram": [], "queue": []}
    seen = set()
    cursor = start
    while cursor < end:
        tag, payload_start, payload_end = _chunk(data, cursor, end, context)
        if tag in {"REGS", "RAM ", "QUEU"}:
            if tag in seen:
                raise _error(context, f"duplicate {tag!r} state chunk")
            seen.add(tag)
            if tag == "REGS":
                state["regs"] = _parse_regs(data, payload_start, payload_end,
                                            f"{context}/REGS")
            elif tag == "RAM ":
                state["ram"] = _parse_ram(data, payload_start, payload_end,
                                          f"{context}/RAM ")
            else:
                state["queue"] = _parse_queue(data, payload_start, payload_end,
                                               f"{context}/QUEU")
        # Unknown state chunks are intentionally skipped by their declared
        # length, as required for MOO format extensibility.
        cursor = payload_end
    return state


def _validate_cycles(data: bytes, start: int, end: int, context: str) -> None:
    """Validate CYCL count and record framing without decoding timing data."""
    count = _u32(data, start, end, context)
    if count != (end - start - 4) // _CYCLE_RECORD_SIZE or (
        end - start - 4
    ) % _CYCLE_RECORD_SIZE:
        raise _error(context, "cycle count does not match 15-byte record framing")


def _parse_test(data: bytes, start: int, end: int, declared_count: int) -> dict:
    context = "TEST"
    if end - start < 4:
        raise _error(context, "missing test index")
    index = _u32(data, start, end, context)
    if index >= declared_count:
        raise _error(context, f"test index {index} is outside declared count {declared_count}")

    test = {"idx": index}
    seen = set()
    cursor = start + 4
    while cursor < end:
        tag, payload_start, payload_end = _chunk(data, cursor, end, context)
        if tag in {"NAME", "BYTS", "INIT", "FINA", "CYCL", "HASH", "EXCP"}:
            if tag in seen:
                raise _error(context, f"duplicate {tag!r} test chunk")
            seen.add(tag)

        if tag == "NAME":
            length = _u32(data, payload_start, payload_end, "TEST/NAME")
            if length != payload_end - payload_start - 4:
                raise _error("TEST/NAME", "name byte count does not match payload length")
            try:
                test["name"] = data[payload_start + 4:payload_end].decode("ascii")
            except UnicodeDecodeError as exc:
                raise _error("TEST/NAME", "name is not ASCII") from exc
        elif tag == "BYTS":
            length = _u32(data, payload_start, payload_end, "TEST/BYTS")
            if length != payload_end - payload_start - 4:
                raise _error("TEST/BYTS", "byte count does not match payload length")
            if length == 0:
                raise _error("TEST/BYTS", "instruction byte list is empty")
            test["bytes"] = list(data[payload_start + 4:payload_end])
        elif tag == "INIT":
            test["initial"] = _parse_state(data, payload_start, payload_end,
                                           "TEST/INIT")
        elif tag == "FINA":
            test["final"] = _parse_state(data, payload_start, payload_end,
                                         "TEST/FINA")
        elif tag == "CYCL":
            _validate_cycles(data, payload_start, payload_end, "TEST/CYCL")
        elif tag == "HASH":
            if payload_end - payload_start != 20:
                raise _error("TEST/HASH", "SHA-1 identity must contain exactly 20 bytes")
            test["hash"] = data[payload_start:payload_end].hex()
        elif tag == "EXCP":
            if payload_end - payload_start != 5:
                raise _error("TEST/EXCP", "exception payload must contain 5 bytes")
            flag_address = int.from_bytes(data[payload_start + 1:payload_end], "little")
            if flag_address > _MAX_RAM_ADDRESS:
                raise _error("TEST/EXCP", "flags address exceeds 24-bit physical space")
            test["exception"] = {
                "number": data[payload_start],
                "flag_address": flag_address,
            }
        # Unknown test chunks are skipped by their declared length.
        cursor = payload_end

    missing = _REQUIRED_TEST_CHUNKS - seen
    if missing:
        raise _error(context, f"missing required chunks: {', '.join(sorted(missing))}")
    return test


def parse_moo(data: bytes) -> dict:
    """Parse one complete C286 MOO file into official-converter-shaped data.

    The returned ``version`` is the MOO major version.  Register and RAM data
    in ``final`` remain deltas exactly as encoded.  CYCL records are validated
    for framing and omitted, so this parser makes no timing claim.
    """
    if not isinstance(data, bytes):
        raise TypeError("parse_moo expects bytes")
    if len(data) < 8:
        raise _error("MOO", "truncated file header")
    if data[:4] != b"MOO ":
        raise _error("MOO", "invalid magic")

    header_length = int.from_bytes(data[4:8], "little")
    if header_length < _MOO_HEADER_MIN_SIZE:
        raise _error("MOO", "header payload is shorter than 12 bytes")
    if header_length > len(data) - 8:
        raise _error("MOO", "header payload extends beyond file")
    header_start = 8
    header_end = header_start + header_length
    header = data[header_start:header_end]

    major = header[0]
    minor = header[1]
    if major != _MOO_MAJOR_VERSION or minor > _MOO_MAX_MINOR_VERSION:
        raise _error("MOO", f"unsupported format version {major}.{minor}")
    if header[2:4] != b"\0\0":
        raise _error("MOO", "reserved header bytes must be zero")
    test_count = int.from_bytes(header[4:8], "little")
    try:
        cpu = header[8:12].decode("ascii").rstrip()
    except UnicodeDecodeError as exc:
        raise _error("MOO", "CPU identifier is not ASCII") from exc
    if cpu != "C286":
        raise _error("MOO", f"expected C286 CPU identifier, got {cpu!r}")

    tests = []
    indices = set()
    cursor = header_end
    while cursor < len(data):
        tag, payload_start, payload_end = _chunk(data, cursor, len(data), "MOO")
        if tag == "TEST":
            test = _parse_test(data, payload_start, payload_end, test_count)
            if test["idx"] in indices:
                raise _error("MOO", f"duplicate test index {test['idx']}")
            indices.add(test["idx"])
            tests.append(test)
        # Metadata and unknown top-level chunks do not affect the official
        # converter's functional test result and are skipped by framing.
        cursor = payload_end

    if len(tests) != test_count:
        raise _error("MOO", f"header declares {test_count} tests but file contains {len(tests)}")
    if indices != set(range(test_count)):
        raise _error("MOO", "test indices must be unique and contiguous from zero")
    return {"version": major, "cpu": cpu, "tests": tests}
