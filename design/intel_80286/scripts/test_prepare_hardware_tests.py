#!/usr/bin/env python3
"""Focused fixtures for physical MOO record normalization and fetching."""

import hashlib
import tempfile
import unittest
from pathlib import Path
import sys
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_hardware_tests as importer


REGISTERS = importer.REGISTERS


def physical_test(code=None, *, cs=0x1234, ip=0x4567, flags=0x0002,
                  final_regs=None, initial_ram=None, final_ram=None,
                  initial_queue=None, final_queue=None, exception=None):
    if code is None:
        code = [0x04, 0x7F, 0xF4]  # ADD AL,7Fh followed by the captured HLT.
    code = list(code)
    regs = {
        "ax": 0x1020, "cx": 0x3040, "dx": 0x5060, "bx": 0x7080,
        "sp": 0x9000, "bp": 0xA000, "si": 0xB000, "di": 0xC000,
        "es": 0x1111, "cs": cs, "ss": 0x2222, "ds": 0x3333,
        "ip": ip, "flags": flags,
    }
    start = cs * 16 + ip
    if initial_ram is None:
        initial_ram = [[start + offset, byte] for offset, byte in enumerate(code)]
        initial_ram.append([0x50000, 0xA5])
    if final_ram is None:
        final_ram = []
    final = {"ip": (ip + len(code)) & 0xFFFF}
    final.update(final_regs or {})
    final.setdefault("cs", cs)
    initial = {
        "regs": regs,
        "ram": initial_ram,
        "queue": [] if initial_queue is None else initial_queue,
    }
    final_state = {
        "regs": final,
        "ram": final_ram,
        "queue": [] if final_queue is None else final_queue,
    }
    test = {"idx": 7, "name": "fixture", "bytes": code,
            "initial": initial, "final": final_state,
            "hash": "0" * 40}
    if exception is not None:
        test["exception"] = exception
    return test


def git_blob_identity(data):
    header = b"blob " + str(len(data)).encode("ascii") + b"\0"
    return hashlib.sha1(header + data).hexdigest()


class NormalizePhysicalTests(unittest.TestCase):
    def test_merges_unchanged_registers_and_ram_and_keeps_final_delta(self):
        test = physical_test(final_regs={"ax": 0x1021, "flags": 0x0003})
        initial, final, code, initial_ram, final_ram, opcode = importer.normalized(
            test, "04.MOO.gz")

        self.assertEqual(initial, test["initial"]["regs"])
        self.assertEqual(final["ax"], 0x1021)
        self.assertEqual(final["cx"], initial["cx"])
        self.assertEqual(final["flags"], 0x0003)
        self.assertEqual(final["ip"], initial["ip"] + len(test["bytes"]))
        self.assertEqual(code, [0x04, 0x7F, 0xF4])
        self.assertEqual(opcode, 0x04)
        self.assertEqual(initial_ram[0x50000], 0xA5)
        self.assertEqual(final_ram, initial_ram)

    def test_segment_prefix_and_post_hlt_pc_use_all_recorded_bytes(self):
        code = [0x26, 0x04, 0x7F, 0xF4]
        test = physical_test(code, final_regs={"ip": (0x4567 + len(code)) & 0xFFFF})
        _, final, parsed_code, _, _, opcode = importer.normalized(test, "04.MOO.gz")
        self.assertEqual(parsed_code, code)
        self.assertEqual(opcode, 0x04)
        self.assertEqual(final["ip"], 0x4567 + 4)

    def test_supports_all_selected_instruction_lengths(self):
        cases = (
            ("04.MOO.gz", [0x04, 0x80, 0xF4], 0x04),
            ("05.MOO.gz", [0x05, 0x34, 0x12, 0xF4], 0x05),
            ("40.MOO.gz", [0x40, 0xF4], 0x40),
        )
        for filename, code, opcode in cases:
            with self.subTest(filename=filename):
                self.assertEqual(importer.normalized(physical_test(code), filename)[-1], opcode)

    def test_adc_sbb_sub_cmp_accept_byte_and_word_immediates(self):
        cases = (
            ("14.MOO.gz", [0x14, 0x7F, 0xF4], 0x14),
            ("15.MOO.gz", [0x15, 0x34, 0x12, 0xF4], 0x15),
            ("1C.MOO.gz", [0x1C, 0x80, 0xF4], 0x1C),
            ("1D.MOO.gz", [0x1D, 0x78, 0x56, 0xF4], 0x1D),
            ("2C.MOO.gz", [0x2C, 0xFF, 0xF4], 0x2C),
            ("2D.MOO.gz", [0x2D, 0xEF, 0xBE, 0xF4], 0x2D),
            ("3C.MOO.gz", [0x3C, 0x10, 0xF4], 0x3C),
            ("3D.MOO.gz", [0x3D, 0x20, 0x10, 0xF4], 0x3D),
        )
        for filename, code, opcode in cases:
            with self.subTest(filename=filename):
                test = physical_test(code)
                initial, final, parsed_code, _, _, parsed_opcode = importer.normalized(
                    test, filename)
                self.assertEqual(parsed_code, code)
                self.assertEqual(parsed_opcode, opcode)
                self.assertEqual(final["ip"], (initial["ip"] + len(code)) & 0xFFFF)
                if opcode in (0x3C, 0x3D):
                    # CMP's captured final-register delta omits AX; merge it from initial.
                    self.assertNotIn("ax", test["final"]["regs"])
                    self.assertEqual(final["ax"], initial["ax"])

    def test_f6_f7_test_alias_register_forms_preserve_captured_operands(self):
        # ModRM C8..CF selects the eight 286 GPR encodings with /1 and mod=3.
        # TEST has no destination writeback; the physical capture often omits
        # unchanged registers, so normalization must merge those from INIT.
        for opcode, filename, immediate in (
                (0xF6, "F6.1.MOO.gz", [0xA5]),
                (0xF7, "F7.1.MOO.gz", [0x34, 0x12])):
            for rm in range(8):
                with self.subTest(opcode=opcode, rm=rm):
                    modrm = 0xC8 | rm
                    code = [opcode, modrm, *immediate, 0xF4]
                    test = physical_test(code, final_regs={"flags": 0x0846})
                    initial, final, parsed, _, _, parsed_opcode = importer.normalized(
                        test, filename)
                    self.assertEqual(parsed, code)
                    self.assertEqual(parsed_opcode, opcode)
                    self.assertEqual(final["ax"], initial["ax"])
                    self.assertEqual(final["cx"], initial["cx"])
                    self.assertEqual(final["ip"], initial["ip"] + len(code))

    def test_test_alias_masks_exclude_undefined_af_only(self):
        self.assertEqual(importer.flags_mask(0xF6), 0x7FC7)
        self.assertEqual(importer.flags_mask(0xF7), 0x7FC7)
        self.assertEqual(importer.flags_mask(0x04), 0x7FD7)
        self.assertEqual(importer.flags_mask(0x4F), 0x7FD7)

    def test_test_alias_allows_segment_prefix_and_checks_full_length(self):
        code = [0x3E, 0xF6, 0xCC, 0x80, 0xF4]  # TEST AH,80h with a segment prefix.
        test = physical_test(code, final_regs={"ip": (0x4567 + len(code)) & 0xFFFF})
        self.assertEqual(importer.normalized(test, "F6.1.MOO.gz")[2], code)

        lock_prefixed = [0xF0, 0xF6, 0xCF, 0x55, 0xF4]
        test = physical_test(lock_prefixed,
                             final_regs={"ip": (0x4567 + len(lock_prefixed)) & 0xFFFF})
        self.assertEqual(importer.normalized(test, "F6.1.MOO.gz")[2], lock_prefixed)

    def test_test_alias_rejects_bad_group_truncation_and_memory_modes(self):
        cases = (
            ("F6.1.MOO.gz", [0xF6, 0xC0, 0x80, 0xF4], "group extension"),
            ("F7.1.MOO.gz", [0xF7, 0xD0, 0x34, 0x12, 0xF4], "group extension"),
            ("F6.1.MOO.gz", [0xF6, 0xC8, 0xF4], "Unsupported encoding"),
            ("F7.1.MOO.gz", [0xF7, 0xC8, 0x34, 0xF4], "Unsupported encoding"),
            ("F6.1.MOO.gz", [0xF6, 0x08, 0x80, 0xF4], "memory form"),
            ("F7.1.MOO.gz", [0xF7, 0x48, 0x00, 0x34, 0x12, 0xF4], "memory form"),
            ("F7.1.MOO.gz", [0xF6, 0xC8, 0x34, 0x12, 0xF4], "Unsupported encoding"),
            ("F6.1.MOO.gz", [0xF6, 0xC8, 0x80, 0x90], "Unsupported encoding"),
        )
        for filename, code, message in cases:
            with self.subTest(filename=filename, code=code), self.assertRaisesRegex(
                    ValueError, message):
                importer.normalized(physical_test(code), filename)

    def test_rejects_malformed_accumulator_immediate_encodings(self):
        cases = (
            ("14.MOO.gz", [0x15, 0x7F, 0xF4]),       # File/opcode mismatch.
            ("15.MOO.gz", [0x15, 0x34, 0xF4]),       # Truncated word immediate.
            ("1C.MOO.gz", [0x1C, 0xF4]),             # Missing byte immediate.
            ("2D.MOO.gz", [0x2D, 0x34, 0xF4]),       # Truncated word immediate.
            ("3C.MOO.gz", [0x3C, 0x10, 0xF4, 0x90]), # Trailing byte after HLT.
        )
        for filename, code in cases:
            with self.subTest(filename=filename, code=code), self.assertRaisesRegex(
                    ValueError, "Unsupported encoding"):
                importer.normalized(physical_test(code), filename)

    def test_all_inc_dec_gpr_opcodes_include_sp(self):
        register_by_encoding = ("ax", "cx", "dx", "bx", "sp", "bp", "si", "di")
        for opcode in range(0x40, 0x50):
            with self.subTest(opcode=opcode):
                filename = f"{opcode:02X}.MOO.gz"
                register = register_by_encoding[opcode & 7]
                delta = 1 if opcode < 0x48 else -1
                before = physical_test()["initial"]["regs"][register]
                expected = (before + delta) & 0xFFFF
                test = physical_test([opcode, 0xF4], final_regs={register: expected})
                initial, final, code, _, _, parsed_opcode = importer.normalized(test, filename)

                self.assertEqual(code, [opcode, 0xF4])
                self.assertEqual(parsed_opcode, opcode)
                self.assertEqual(final[register], expected)
                self.assertEqual(final["sp"], expected if register == "sp" else initial["sp"])

    def test_rejects_malformed_inc_dec_encodings(self):
        cases = (
            ("41.MOO.gz", [0x40, 0xF4]),       # File/opcode mismatch.
            ("4A.MOO.gz", [0x4A, 0x00, 0xF4]), # INC/DEC has no immediate byte.
            ("4F.MOO.gz", [0x4F]),             # Missing captured HLT.
            ("40.MOO.gz", [0xF0, 0x40, 0xF4]), # Unsupported LOCK prefix.
        )
        for filename, code in cases:
            with self.subTest(filename=filename, code=code), self.assertRaisesRegex(
                    ValueError, "Unsupported encoding"):
                importer.normalized(physical_test(code), filename)

    def test_rejects_incomplete_initial_and_unexpected_final_register_state(self):
        missing_initial = physical_test()
        del missing_initial["initial"]["regs"]["bp"]
        with self.assertRaisesRegex(ValueError, "Incomplete physical initial"):
            importer.normalized(missing_initial, "04.MOO.gz")

        unexpected_final = physical_test(final_regs={"future": 1})
        with self.assertRaisesRegex(ValueError, "Unexpected physical final"):
            importer.normalized(unexpected_final, "04.MOO.gz")

    def test_rejects_if_tf_exceptions_and_prefetch_queues(self):
        for flag in (0x0100, 0x0200, 0x0300):
            with self.subTest(flag=flag), self.assertRaisesRegex(ValueError, "IF/TF"):
                importer.normalized(physical_test(flags=0x0002 | flag), "04.MOO.gz")

        cases = (
            (physical_test(exception={"number": 13, "flag_address": 0x70000}), "exception"),
            (physical_test(initial_queue=[0x04]), "prefetch queue"),
            (physical_test(final_queue=[0xF4]), "prefetch queue"),
        )
        for test, message in cases:
            with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
                importer.normalized(test, "04.MOO.gz")

    def test_rejects_initial_flags_not_loadable_by_real_mode_popf(self):
        for flags in (0x1002, 0x2002, 0x4002, 0x7002):
            with self.subTest(flags=flags), self.assertRaisesRegex(ValueError, 'IOPL/NT'):
                importer.normalized(physical_test(flags=flags), '04.MOO.gz')

    def test_rejects_wrong_post_hlt_pc_or_code_segment(self):
        for patch_fields in ({"ip": 0x4569}, {"cs": 0x1235}):
            test = physical_test(final_regs=patch_fields)
            with self.subTest(patch_fields=patch_fields), self.assertRaisesRegex(ValueError, "post-HLT PC"):
                importer.normalized(test, "04.MOO.gz")

    def test_rejects_memory_changes_and_instruction_bytes_not_in_ram(self):
        changed_memory = physical_test(final_ram=[[0x50000, 0xA4]])
        with self.assertRaisesRegex(ValueError, "memory changes"):
            importer.normalized(changed_memory, "04.MOO.gz")

        mismatch = physical_test()
        mismatch["initial"]["ram"][0][1] ^= 1
        with self.assertRaisesRegex(ValueError, "encoded instruction differs"):
            importer.normalized(mismatch, "04.MOO.gz")

    def test_rejects_wrong_opcode_encoding_or_missing_halt(self):
        cases = (
            ("05.MOO.gz", [0x04, 0x7F, 0xF4]),
            ("04.MOO.gz", [0x04, 0x7F, 0x90]),
            ("05.MOO.gz", [0x05, 0x34, 0xF4]),
        )
        for filename, code in cases:
            with self.subTest(filename=filename, code=code), self.assertRaisesRegex(ValueError, "Unsupported encoding"):
                importer.normalized(physical_test(code), filename)


class FetchIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.destination = Path(self.temp.name)
        self.payload = b"small fixture payload"
        self.file_map = {
            "fixture.bin": (git_blob_identity(self.payload), len(self.payload)),
        }

    def patched_fetch(self, **patches):
        stack = patch.multiple(importer, DEST=self.destination, FILES=self.file_map, **patches)
        return stack

    def test_downloaded_blob_is_verified_and_cached_with_manifest(self):
        response = MagicMock()
        response.__enter__.return_value.read.return_value = self.payload
        with self.patched_fetch(), patch.object(importer.urllib.request, "urlopen",
                                                  return_value=response) as urlopen:
            data, manifest = importer.fetch("fixture.bin")

        self.assertEqual(data, self.payload)
        self.assertEqual(manifest["git_blob"], self.file_map["fixture.bin"][0])
        self.assertEqual(manifest["bytes"], len(self.payload))
        self.assertEqual(manifest["sha256"], hashlib.sha256(self.payload).hexdigest())
        self.assertEqual((self.destination / "fixture.bin").read_bytes(), self.payload)
        urlopen.assert_called_once()

    def test_corrupt_cached_blob_is_rejected_without_network_fallback(self):
        cached = self.destination / "fixture.bin"
        cached.write_bytes(b"corrupt cached bytes")
        with self.patched_fetch(), patch.object(importer.urllib.request, "urlopen") as urlopen:
            with self.assertRaisesRegex(ValueError, "Git-blob mismatch"):
                importer.fetch("fixture.bin")
        urlopen.assert_not_called()

    def test_corrupt_download_is_rejected_and_not_cached(self):
        response = MagicMock()
        response.__enter__.return_value.read.return_value = b"truncated"
        with self.patched_fetch(), patch.object(importer.urllib.request, "urlopen",
                                                  return_value=response):
            with self.assertRaisesRegex(ValueError, "Git-blob mismatch"):
                importer.fetch("fixture.bin")
        self.assertFalse((self.destination / "fixture.bin").exists())


if __name__ == "__main__":
    unittest.main()
