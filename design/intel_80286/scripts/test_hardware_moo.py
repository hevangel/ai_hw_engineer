#!/usr/bin/env python3
"""Fixtures for the strict MOO functional-state adapter."""

import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hardware_moo import parse_moo


def u32(value):
    return value.to_bytes(4, "little")


def chunk(tag, payload):
    tag_bytes = tag.encode("ascii")
    if len(tag_bytes) != 4:
        raise ValueError("fixture chunk tags must be four bytes")
    return tag_bytes + u32(len(payload)) + payload


def regs_chunk(values):
    order = ("ax", "bx", "cx", "dx", "cs", "ss", "ds", "es",
             "sp", "bp", "si", "di", "ip", "flags")
    mask = sum(1 << index for index, name in enumerate(order) if name in values)
    payload = mask.to_bytes(2, "little")
    payload += b"".join(values[name].to_bytes(2, "little")
                        for name in order if name in values)
    return chunk("REGS", payload)


def ram_chunk(entries):
    return chunk("RAM ", u32(len(entries)) + b"".join(
        address.to_bytes(4, "little") + bytes((value,))
        for address, value in entries
    ))


def state_chunk(tag, regs, ram=(), queue=(), extras=b""):
    payload = regs_chunk(regs) + ram_chunk(list(ram))
    payload += chunk("QUEU", u32(len(queue)) + bytes(queue))
    return chunk(tag, payload + extras)


def sample_test(index=0, extra_test_chunks=b"", initial_extra=b"",
                final_extra=b"", hash_data=None, cycle_data=None,
                name_data=None, byte_data=None):
    name = b"add [bx+0Eh],bl"
    name_chunk = (chunk("NAME", u32(len(name)) + name)
                  if name_data is None else name_data)
    opcode = bytes((0, 95, 14, 244))
    byte_chunk = (chunk("BYTS", u32(len(opcode)) + opcode)
                  if byte_data is None else byte_data)

    initial_regs = {
        "ax": 715, "bx": 26659, "cx": 49548, "dx": 64181,
        "cs": 65535, "ss": 41175, "ds": 65535, "es": 43996,
        "sp": 39769, "bp": 65535, "si": 35262, "di": 34633,
        "ip": 38072, "flags": 6291,
    }
    initial_ram = [
        [1086632, 0], [1086633, 95], [1086634, 14], [1086635, 244],
        [1086636, 161], [1086637, 214], [1086638, 248], [1086639, 46],
        [1086640, 107], [1086641, 166], [1075233, 222],
    ]
    final_regs = {"ip": 38076, "flags": 19}
    final_ram = [[1075233, 1]]

    init = state_chunk("INIT", initial_regs, initial_ram, extras=initial_extra)
    final = state_chunk("FINA", final_regs, final_ram, extras=final_extra)
    if hash_data is None:
        # Identity shown in the pinned SingleStepTests README's example.
        hash_data = bytes.fromhex("626be5084b331080eb08256c12a62d24afdf2a03")
    if cycle_data is None:
        cycle_data = chunk("CYCL", u32(0))
    payload = u32(index) + name_chunk + byte_chunk + init + final + cycle_data
    payload += chunk("HASH", hash_data) + extra_test_chunks
    return chunk("TEST", payload)


def moo_file(tests, count=None, *, major=1, minor=1, reserved=b"\0\0",
             cpu=b"C286", header_extra=b"", top_extra=b""):
    if count is None:
        count = len(tests)
    header = bytes((major, minor)) + reserved + u32(count) + cpu + header_extra
    return b"MOO " + u32(len(header)) + header + top_extra + b"".join(tests)


class HardwareMooTests(unittest.TestCase):
    def test_external_readme_example_preserves_initial_state_and_final_delta(self):
        parsed = parse_moo(moo_file([sample_test()]))
        self.assertEqual(parsed["version"], 1)
        self.assertEqual(parsed["cpu"], "C286")
        self.assertEqual(len(parsed["tests"]), 1)
        test = parsed["tests"][0]
        self.assertEqual(test["idx"], 0)
        self.assertEqual(test["name"], "add [bx+0Eh],bl")
        self.assertEqual(test["bytes"], [0, 95, 14, 244])
        self.assertEqual(test["hash"], "626be5084b331080eb08256c12a62d24afdf2a03")
        self.assertEqual(test["initial"]["regs"], {
            "ax": 715, "bx": 26659, "cx": 49548, "dx": 64181,
            "cs": 65535, "ss": 41175, "ds": 65535, "es": 43996,
            "sp": 39769, "bp": 65535, "si": 35262, "di": 34633,
            "ip": 38072, "flags": 6291,
        })
        self.assertEqual(test["initial"]["ram"], [
            [1086632, 0], [1086633, 95], [1086634, 14], [1086635, 244],
            [1086636, 161], [1086637, 214], [1086638, 248], [1086639, 46],
            [1086640, 107], [1086641, 166], [1075233, 222],
        ])
        self.assertEqual(test["initial"]["queue"], [])
        self.assertEqual(test["final"], {
            "regs": {"ip": 38076, "flags": 19},
            "ram": [[1075233, 1]],
            "queue": [],
        })
        self.assertNotIn("cycles", test)

    def test_exception_is_optional_and_decoded(self):
        test = sample_test(extra_test_chunks=chunk("EXCP", bytes((13,)) + u32(461420)))
        parsed = parse_moo(moo_file([test]))
        self.assertEqual(parsed["tests"][0]["exception"], {
            "number": 13, "flag_address": 461420,
        })

    def test_unknown_framed_chunks_are_skipped(self):
        test = sample_test(
            extra_test_chunks=chunk("FUTR", b"future test data"),
            initial_extra=chunk("XTRA", b"future state data"),
        )
        parsed = parse_moo(moo_file([test], top_extra=chunk("META", b"metadata")))
        self.assertEqual(parsed["tests"][0]["bytes"], [0, 95, 14, 244])

    def test_cycle_records_are_framed_but_not_returned(self):
        one_cycle = chunk("CYCL", u32(1) + bytes(15))
        test = sample_test(cycle_data=one_cycle)
        parsed_test = parse_moo(moo_file([test]))["tests"][0]
        self.assertNotIn("cycles", parsed_test)

    def test_bad_magic_and_truncated_header_are_rejected(self):
        for raw in (b"MOO", b"NOPE" + bytes(20)):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                parse_moo(raw)

    def test_header_length_version_reserved_and_cpu_are_validated(self):
        valid_test = sample_test()
        invalid_headers = (
            moo_file([valid_test], header_extra=b"", major=2),
            moo_file([valid_test], header_extra=b"", minor=2),
            moo_file([valid_test], reserved=b"\0\1"),
            moo_file([valid_test], cpu=b"8086"),
            b"MOO " + u32(11) + bytes(11),
            b"MOO " + u32(100) + bytes(12),
        )
        for raw in invalid_headers:
            with self.subTest(raw=raw[:16]), self.assertRaises(ValueError):
                parse_moo(raw)

    def test_header_test_count_must_match_and_indices_must_be_unique(self):
        with self.assertRaisesRegex(ValueError, "declares 2 tests"):
            parse_moo(moo_file([sample_test(0)], count=2))
        with self.assertRaisesRegex(ValueError, "duplicate test index"):
            parse_moo(moo_file([sample_test(0), sample_test(0)], count=2))
        with self.assertRaisesRegex(ValueError, "outside declared count"):
            parse_moo(moo_file([sample_test(1)], count=1))

    def test_truncated_or_out_of_bounds_top_level_chunks_are_rejected(self):
        valid = moo_file([sample_test()])
        for suffix in (b"x", b"FUTR" + u32(10) + b"x"):
            with self.subTest(suffix=suffix), self.assertRaises(ValueError):
                parse_moo(valid + suffix)

    def test_duplicate_critical_chunks_are_rejected(self):
        duplicate_name = chunk("NAME", u32(0))
        with self.assertRaisesRegex(ValueError, "duplicate 'NAME'"):
            parse_moo(moo_file([sample_test(extra_test_chunks=duplicate_name)]))

        duplicate_regs = regs_chunk({})
        with self.assertRaisesRegex(ValueError, "duplicate 'REGS'"):
            parse_moo(moo_file([sample_test(initial_extra=duplicate_regs)]))

    def test_name_and_instruction_redundant_lengths_are_checked(self):
        bad_name = chunk("NAME", u32(9) + b"x")
        bad_bytes = chunk("BYTS", u32(3) + bytes((0, 95, 14, 244)))
        for bad_chunk, expected in ((bad_name, "TEST/NAME"),
                                    (bad_bytes, "TEST/BYTS")):
            with self.subTest(expected=expected), self.assertRaisesRegex(ValueError, expected):
                kwargs = {"name_data": bad_chunk} if expected == "TEST/NAME" else {
                    "byte_data": bad_chunk,
                }
                parse_moo(moo_file([sample_test(**kwargs)]))

    def test_register_mask_and_register_value_boundaries_are_checked(self):
        too_many_values = chunk("REGS", (1).to_bytes(2, "little"))
        reserved_register = chunk("REGS", (1 << 15).to_bytes(2, "little") + b"\0\0")
        malformed_state = chunk("INIT", too_many_values)
        for state in (malformed_state, chunk("INIT", reserved_register)):
            bad_payload = u32(0) + chunk("NAME", u32(0)) + chunk("BYTS", u32(1) + b"\x90")
            bad_payload += state + state_chunk("FINA", {}) + chunk("HASH", bytes(20))
            with self.subTest(state=state), self.assertRaises(ValueError):
                parse_moo(moo_file([chunk("TEST", bad_payload)]))

    def test_ram_and_queue_counts_addresses_and_duplicates_are_checked(self):
        bad_ram = chunk("RAM ", u32(1))
        high_ram = ram_chunk([(0x1000000, 0)])
        duplicate_ram = ram_chunk([(4, 1), (4, 2)])
        bad_queue = chunk("QUEU", u32(2) + b"\x01")
        for malformed, error in ((bad_ram, "RAM entry count"),
                                  (high_ram, "exceeds 24-bit"),
                                  (duplicate_ram, "duplicate RAM address"),
                                  (bad_queue, "queue byte count")):
            state = chunk("INIT", regs_chunk({}) + malformed)
            payload = u32(0) + chunk("NAME", u32(0)) + chunk("BYTS", u32(1) + b"\x90")
            payload += state + state_chunk("FINA", {}) + chunk("HASH", bytes(20))
            with self.subTest(error=error), self.assertRaisesRegex(ValueError, error):
                parse_moo(moo_file([chunk("TEST", payload)]))

    def test_hash_exception_and_cycle_payloads_are_length_checked(self):
        malformed_test_chunks = (
            chunk("EXCP", bytes(4)),
            chunk("EXCP", bytes((13,)) + u32(0x1000000)),
        )
        for extra in malformed_test_chunks:
            with self.subTest(extra=extra[:4]), self.assertRaises(ValueError):
                parse_moo(moo_file([sample_test(extra_test_chunks=extra)]))
        with self.assertRaisesRegex(ValueError, "exactly 20 bytes"):
            parse_moo(moo_file([sample_test(hash_data=bytes(19))]))
        with self.assertRaisesRegex(ValueError, "cycle count"):
            parse_moo(moo_file([sample_test(cycle_data=chunk("CYCL", u32(1)))]))


if __name__ == "__main__":
    unittest.main()
