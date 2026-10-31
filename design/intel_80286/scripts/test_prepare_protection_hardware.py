#!/usr/bin/env python3
"""Fixtures for the external F7 /1 vector-13 physical capture importer."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_protection_hardware as importer


REGISTERS = importer.hardware.REGISTERS


def physical_fault(*, code=None, idx=7, digest='a' * 40, flags=0x0002,
                   exception_number=13, flag_address=None, initial_ram=None,
                   final_ram=None, initial_regs=None, final_regs=None):
    if code is None:
        # TEST word [FFFFh],1234h; followed by the source's stop HLT.
        code = [0xf7, 0x0e, 0xff, 0xff, 0x34, 0x12, 0xf4]
    code = list(code)
    regs = {
        'ax':0x1234, 'cx':0x2345, 'dx':0x3456, 'bx':0x4567,
        'sp':0x8000, 'bp':0x5678, 'si':0x6789, 'di':0x789a,
        'es':0x1111, 'cs':0x1000, 'ss':0x1000, 'ds':0x2222,
        'ip':0x0100, 'flags':flags,
    }
    regs.update(initial_regs or {})
    start = regs['cs'] * 16 + regs['ip']
    if initial_ram is None:
        initial_ram = [[start + offset, byte] for offset, byte in enumerate(code)]
        initial_ram += [[0x20100, 0xf4], [0x30000, 0xa5],
                        [0x17ffa, 0xaa], [0x17ffb, 0xbb]]
    if flag_address is None:
        flag_address = regs['ss'] * 16 + 0x7ffe
    final = {'cs':0x2000, 'sp':0x7ffa, 'ip':0x0101, 'flags':flags}
    final.update(final_regs or {})
    if final_ram is None:
        # Full captured frame delta: IP, CS, FLAGS in little endian order.
        final_ram = [[0x17ffa, 0x00], [0x17ffb, 0x01],
                     [0x17ffc, 0x00], [0x17ffd, 0x10],
                     [0x17ffe, flags & 0xff], [0x17fff, flags >> 8]]
    return {
        'idx':idx,
        'hash':digest,
        'bytes':code,
        'initial':{'regs':regs, 'ram':initial_ram, 'queue':[]},
        'final':{'regs':final, 'ram':final_ram, 'queue':[]},
        'exception':{'number':exception_number, 'flag_address':flag_address},
    }


class NormalizeProtectionFaultTests(unittest.TestCase):
    def test_merges_unchanged_registers_and_full_ram_while_preserving_frame_delta(self):
        test = physical_fault(final_regs={'ip':0x0101})
        record = importer.normalize_fault(test)

        self.assertEqual(record['initial'], test['initial']['regs'])
        self.assertEqual(record['final']['ax'], record['initial']['ax'])
        self.assertEqual(record['final']['cs'], 0x2000)
        self.assertEqual(record['final']['sp'], 0x7ffa)
        self.assertEqual(record['exception_number'], 13)
        self.assertEqual(record['flags_mask'], 0x7fd7)
        self.assertEqual(record['metadata']['exception']['flag_address'],
                         test['exception']['flag_address'])
        self.assertEqual(record['final_ram'][0x30000], 0xa5)
        self.assertEqual(record['final_ram'][0x17ffa], 0x00)
        self.assertEqual(record['final_ram'][0x17ffb], 0x01)
        self.assertEqual(record['final_ram'][0x17ffe], 0x02)
        self.assertEqual(record['initial_ram'][0x17ffa], 0xaa)
        self.assertEqual(record['metadata']['expected_entry_cs'], 0x2000)
        self.assertEqual(record['metadata']['expected_entry_ip'], 0x0100)
        self.assertEqual(record['metadata']['expected_entry_physical'], 0x20100)
        self.assertTrue(record['metadata']['handler_entry_hlt_validated'])
        self.assertTrue(record['metadata']['handler_entry_ram_unchanged'])
        self.assertNotEqual(record['metadata']['expected_entry_ip'],
                            (record['initial']['ip'] + len(record['code'])) & 0xffff)

    def test_accepts_prefix_f0_and_real_11_byte_test_alias_packet(self):
        examples = (
            [0xf0,0xf7,0x0e,0xff,0xff,0x34,0x12,0xf4],
            [0x26,0x3e,0x36,0x36,0x26,0xf7,0x8b,0x44,0xf7,0xf9,0x57,0xf4],
        )
        for code in examples:
            with self.subTest(code=bytes(code).hex()):
                record = importer.normalize_fault(physical_fault(code=code))
                self.assertEqual(record['code'], code)
                self.assertEqual(record['opcode'], 0xf7)

    def test_missing_trailing_source_hlt_is_reported_without_synthesizing_ram(self):
        test = physical_fault()
        code_start = test['initial']['regs']['cs'] * 16 + test['initial']['regs']['ip']
        hlt_address = code_start + len(test['bytes']) - 1
        test['initial']['ram'] = [entry for entry in test['initial']['ram']
                                  if entry[0] != hlt_address]
        record = importer.normalize_fault(test)

        self.assertTrue(record['metadata']['source_code_hlt_missing_from_initial_ram'])
        self.assertNotIn(hlt_address, record['initial_ram'])
        self.assertNotIn(hlt_address, record['final_ram'])
        self.assertEqual(record['code'][-1], 0xf4)

    def test_rejects_missing_or_changed_external_exception_successor_hlt(self):
        test = physical_fault()
        test['initial']['ram'] = [entry for entry in test['initial']['ram']
                                  if entry[0] != 0x20100]
        with self.assertRaisesRegex(ValueError, 'successor is not an initial-RAM HLT'):
            importer.normalize_fault(test)

        test = physical_fault(final_ram=[[0x20100, 0x90]])
        with self.assertRaisesRegex(ValueError, 'successor HLT changed in final RAM'):
            importer.normalize_fault(test)

    def test_rejects_missing_or_mismatched_faulting_instruction_bytes(self):
        test = physical_fault()
        start = test['initial']['regs']['cs'] * 16 + test['initial']['regs']['ip']
        test['initial']['ram'] = [entry for entry in test['initial']['ram']
                                  if entry[0] != start + 2]
        with self.assertRaisesRegex(ValueError, 'instruction byte is missing'):
            importer.normalize_fault(test)

        test = physical_fault()
        test['initial']['ram'][0][1] ^= 1
        with self.assertRaisesRegex(ValueError, 'differs from initial RAM'):
            importer.normalize_fault(test)

    def test_rejects_unloadable_initial_flags(self):
        for flag_bits in (0x0100, 0x0200, 0x1000, 0x2000, 0x4000, 0x7000):
            with self.subTest(flag_bits=flag_bits), self.assertRaisesRegex(
                    ValueError, 'IF/TF|IOPL/NT'):
                importer.normalize_fault(physical_fault(flags=0x0002 | flag_bits))

    def test_rejects_wrong_exception_or_incomplete_state(self):
        with self.assertRaisesRegex(ValueError, 'exception 13'):
            importer.normalize_fault(physical_fault(exception_number=6))

        test = physical_fault()
        del test['initial']['regs']['bp']
        with self.assertRaisesRegex(ValueError, 'Incomplete physical initial'):
            importer.normalize_fault(test)

        with self.assertRaisesRegex(ValueError, 'prefetch queue'):
            test = physical_fault()
            test['final']['queue'] = [0xf4]
            importer.normalize_fault(test)

    def test_rejects_wrong_encoding_and_invalid_hash_or_exception_address(self):
        cases = (
            physical_fault(code=[0xf7,0x06,0xff,0xff,0x34,0x12,0xf4]), # /0, not /1
            physical_fault(code=[0xf6,0x0e,0xff,0xff,0x34,0xf4]),      # wrong opcode file
            physical_fault(code=[0xf7,0x0e,0xff,0xff,0x34,0xf4]),      # truncated word immediate
            physical_fault(digest='A' * 40),
            physical_fault(flag_address=0x1000000),
        )
        for test in cases:
            with self.subTest(test=test), self.assertRaises(ValueError):
                importer.normalize_fault(test)

    def test_collection_accounts_normal_rows_and_revoked_faults_explicitly(self):
        fault = physical_fault(digest='b' * 40)
        normal = physical_fault(digest='c' * 40)
        del normal['exception']
        records, accounting = importer.collect_faults([fault, normal], set())
        self.assertEqual(len(records), 1)
        self.assertEqual(accounting['normal_out_of_scope'], 1)
        self.assertEqual(accounting['selected_faults'], 1)

        records, accounting = importer.collect_faults([fault], {'b' * 40})
        self.assertEqual(records, [])
        self.assertEqual(accounting['selected_revoked'], 1)
        self.assertEqual(accounting['selected_revoked_hashes'], ['b' * 40])

    def test_vector_header_and_ram_rows_keep_the_external_exception_shape(self):
        record = importer.normalize_fault(physical_fault())
        text = importer.render_vectors([record])
        self.assertIn('HWFAULT F7.1.MOO.gz:7:' + 'a' * 40 +
                      ' f70effff3412f4 f7 7fd7 d\n', text)
        self.assertIn('INITIAL ' + ' '.join(
            f"{record['initial'][key]:x}" for key in REGISTERS) + '\n', text)
        self.assertIn('FINAL ' + ' '.join(
            f"{record['final'][key]:x}" for key in REGISTERS) + '\n', text)
        self.assertIn('RAM_FINAL ', text)
        self.assertTrue(text.endswith('END\n'))


class RevocationTests(unittest.TestCase):
    def test_parses_only_lowercase_sha1_ids(self):
        parsed = importer._validate_revocations(b'# pinned\n' + b'a' * 40 + b'\n')
        self.assertEqual(parsed, {'a' * 40})
        with self.assertRaisesRegex(ValueError, 'Malformed'):
            importer._validate_revocations(b'A' * 40 + b'\n')


if __name__ == '__main__':
    unittest.main()
