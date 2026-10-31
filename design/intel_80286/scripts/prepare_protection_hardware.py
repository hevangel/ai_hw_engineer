#!/usr/bin/env python3
"""Import pinned physical F7 /1 #GP13 records without generating expectations."""

from __future__ import annotations

import gzip
import hashlib
import json
from pathlib import Path
import re

import prepare_hardware_tests as hardware
from hardware_moo import parse_moo


SOURCE_PATH = 'v1_real_mode/F7.1.MOO.gz'
REVOCATION_PATH = 'revocation_list.txt'
VECTOR_PATH = hardware.DEST / 'protection_vectors.txt'
MANIFEST_PATH = hardware.DEST / 'protection_manifest.json'
FAULT_VECTOR = 13
FAULT_MASK = 0x7FD7
EXPECTED_SOURCE_RECORDS = 5000
EXPECTED_FAULT_RECORDS = 52
EXPECTED_NORMAL_RECORDS = EXPECTED_SOURCE_RECORDS - EXPECTED_FAULT_RECORDS
_SHA1_RE = re.compile(r'^[0-9a-f]{40}$')


def _validate_revocations(data: bytes) -> set[str]:
    try:
        lines = data.decode('ascii').splitlines()
    except UnicodeDecodeError as exc:
        raise ValueError('Pinned physical-test revocation list is not ASCII') from exc
    hashes = set()
    for line in lines:
        value = line.strip()
        if not value or value.startswith('#'):
            continue
        if not _SHA1_RE.fullmatch(value):
            raise ValueError('Malformed pinned physical-test revocation')
        hashes.add(value)
    return hashes


def normalize_fault(test: dict, filename: str = 'F7.1.MOO.gz') -> dict:
    """Validate and merge one externally captured TEST /1 vector-13 record.

    ``bytes`` retains the source's complete instruction packet and trailing
    HLT.  RAM is merged from the captured initial image and final deltas; no
    exception-frame writes or other memory changes are discarded.
    """
    try:
        initial_state = test['initial']
        final_state = test['final']
        initial = dict(initial_state['regs'])
        final_delta = dict(final_state['regs'])
        initial_ram_entries = initial_state['ram']
        final_ram_entries = final_state['ram']
        initial_queue = initial_state['queue']
        final_queue = final_state['queue']
        exception = test['exception']
        code = list(test['bytes'])
        idx = test['idx']
        digest = test['hash']
    except (KeyError, TypeError) as exc:
        raise ValueError('Incomplete physical #GP record') from exc

    if set(initial) != set(hardware.REGISTERS):
        raise ValueError(f'Incomplete physical initial register state: {filename}:{idx}')
    if not set(final_delta).issubset(hardware.REGISTERS):
        raise ValueError(f'Unexpected physical final register field: {filename}:{idx}')
    if not isinstance(digest, str) or not _SHA1_RE.fullmatch(digest):
        raise ValueError(f'Malformed physical test hash: {filename}:{idx}')
    if not isinstance(idx, int) or idx < 0:
        raise ValueError(f'Malformed physical test index: {filename}')
    if not isinstance(exception, dict) or exception.get('number') != FAULT_VECTOR:
        raise ValueError(f'Expected captured exception 13: {filename}:{idx}')
    flag_address = exception.get('flag_address')
    if not isinstance(flag_address, int) or not 0 <= flag_address <= 0xFFFFFF:
        raise ValueError(f'Malformed exception FLAGS address: {filename}:{idx}')

    if initial['flags'] & 0x0300:
        raise ValueError(f'Physical IF/TF case needs explicit interrupt/debug replay: {filename}:{idx}')
    if initial['flags'] & 0x7000:
        raise ValueError(f'Physical IOPL/NT case cannot be initialized through real-mode POPF: {filename}:{idx}')
    if initial_queue or final_queue:
        raise ValueError(f'Physical prefetch queue replay is not implemented: {filename}:{idx}')

    code = bytes(code)
    opcode, modrm = hardware._decode_encoding(code, filename)
    if opcode != 0xF7 or modrm is None or ((modrm >> 3) & 7) != 1:
        raise ValueError(f'Expected physical F7 /1 TEST record: {filename}:{idx}')
    if code[-1] != 0xF4:
        raise ValueError(f'Physical fault packet is missing its trailing HLT: {filename}:{idx}')

    final = dict(initial)
    final.update(final_delta)
    initial_ram = dict(initial_ram_entries)
    final_ram = dict(initial_ram)
    final_ram.update(final_ram_entries)

    start = initial['cs'] * 16 + initial['ip']
    missing_source_hlt = False
    for offset, byte in enumerate(code):
        address = start + offset
        if address not in initial_ram:
            if offset == len(code) - 1 and byte == 0xF4:
                # Some converters append a stop byte that is absent from the
                # serialized initial RAM.  Preserve that absence and report it.
                missing_source_hlt = True
                continue
            raise ValueError(f'Captured instruction byte is missing from initial RAM: {filename}:{idx}:{offset}')
        if initial_ram[address] != byte:
            raise ValueError(f'Captured instruction differs from initial RAM: {filename}:{idx}:{offset}')

    entry_cs = final['cs']
    entry_ip = (final['ip'] - 1) & 0xFFFF
    entry_address = entry_cs * 16 + entry_ip
    entry_hlt_value = initial_ram.get(entry_address)
    if entry_hlt_value != 0xF4:
        raise ValueError(f'Captured exception successor is not an initial-RAM HLT: {filename}:{idx}')
    if final_ram.get(entry_address) != 0xF4:
        raise ValueError(f'Captured exception successor HLT changed in final RAM: {filename}:{idx}')

    label = f'{Path(filename).name}:{idx}:{digest}'
    metadata = {
        'idx': idx,
        'hash': digest,
        'exception': {'number': FAULT_VECTOR, 'flag_address': flag_address},
        'bytes_hex': code.hex(),
        'initial_cs': initial['cs'],
        'initial_ip': initial['ip'],
        'final_cs': final['cs'],
        'final_ip': final['ip'],
        'expected_entry_cs': entry_cs,
        'expected_entry_ip': entry_ip,
        'expected_entry_physical': entry_address,
        'initial_sp': initial['sp'],
        'final_sp': final['sp'],
        'source_code_hlt_missing_from_initial_ram': missing_source_hlt,
        'handler_entry_ram_byte': entry_hlt_value,
        'handler_entry_hlt_validated': True,
        'handler_entry_ram_unchanged': True,
    }
    return {
        'label': label,
        'code': list(code),
        'opcode': opcode,
        'flags_mask': FAULT_MASK,
        'exception_number': FAULT_VECTOR,
        'initial': initial,
        'final': final,
        'initial_ram': initial_ram,
        'final_ram': final_ram,
        'metadata': metadata,
    }


def collect_faults(tests: list[dict], revoked_hashes: set[str]) -> tuple[list[dict], dict]:
    """Select only non-revoked vector-13 captures; account for all other rows."""
    selected = []
    seen_hashes = set()
    normal_out_of_scope = 0
    selected_revoked = []
    source_revoked_hashes = []
    for test in tests:
        digest = test.get('hash')
        if not isinstance(digest, str) or not _SHA1_RE.fullmatch(digest):
            raise ValueError('Malformed physical test hash in F7.1 source')
        exception = test.get('exception')
        if digest in revoked_hashes:
            source_revoked_hashes.append(digest)
        if exception is None:
            normal_out_of_scope += 1
            continue
        if not isinstance(exception, dict) or exception.get('number') != FAULT_VECTOR:
            raise ValueError(f'Unexpected exception in F7.1 source: {digest}')
        if digest in revoked_hashes:
            selected_revoked.append(digest)
            continue
        if digest in seen_hashes:
            raise ValueError(f'Duplicate selected physical fault hash: {digest}')
        seen_hashes.add(digest)
        selected.append(normalize_fault(test))

    accounting = {
        'source_records': len(tests),
        'selected_faults': len(selected),
        'normal_out_of_scope': normal_out_of_scope,
        'selected_revoked': len(selected_revoked),
        'revoked_hashes_found_in_source': source_revoked_hashes,
        'selected_revoked_hashes': selected_revoked,
    }
    return selected, accounting


def render_vectors(records: list[dict]) -> str:
    lines = []
    for record in records:
        lines.append(
            f"HWFAULT {record['label']} {bytes(record['code']).hex()} "
            f"f7 {record['flags_mask']:x} {record['exception_number']:x}"
        )
        for tag in ('INITIAL', 'FINAL'):
            regs = record[tag.lower()]
            lines.append(tag + ' ' + ' '.join(f'{regs[key]:x}' for key in hardware.REGISTERS))
        for tag in ('RAM_INITIAL', 'RAM_FINAL'):
            ram = record['initial_ram'] if tag == 'RAM_INITIAL' else record['final_ram']
            lines.append(f'{tag} {len(ram):x}' + ''.join(
                f' {address:x} {byte:x}' for address, byte in sorted(ram.items())))
        lines.append('END')
    return '\n'.join(lines) + ('\n' if lines else '')


def prepare(source_bytes: bytes, revocation_bytes: bytes) -> tuple[str, dict]:
    image = parse_moo(gzip.decompress(source_bytes))
    if image['cpu'] != 'C286' or image['version'] != 1:
        raise ValueError('Pinned F7.1 artifact is not a supported C286 MOO image')
    revoked = _validate_revocations(revocation_bytes)
    records, accounting = collect_faults(image['tests'], revoked)
    if accounting['source_records'] != EXPECTED_SOURCE_RECORDS:
        raise ValueError(f"Expected {EXPECTED_SOURCE_RECORDS} F7.1 records, got {accounting['source_records']}")
    if accounting['selected_faults'] != EXPECTED_FAULT_RECORDS:
        raise ValueError(f"Expected {EXPECTED_FAULT_RECORDS} non-revoked #GP13 records, got {accounting['selected_faults']}")
    if accounting['normal_out_of_scope'] != EXPECTED_NORMAL_RECORDS:
        raise ValueError(f"Expected {EXPECTED_NORMAL_RECORDS} normal records out of scope, got {accounting['normal_out_of_scope']}")
    if accounting['selected_revoked']:
        raise ValueError('Pinned F7.1 #GP13 records include revoked captures')
    text = render_vectors(records)
    missing_source_hlts = [record['label'] for record in records
                           if record['metadata']['source_code_hlt_missing_from_initial_ram']]
    metadata = {
        'revision': hardware.REVISION,
        'scope': 'Pinned physical real-mode F7 /1 exception-13 captures; functional register/flags/frame replay with exact source state, no timing claim',
        **accounting,
        'normal_out_of_scope_reason': 'normal F7.1 completion, outside the architectural exception adapter',
        'selected_revoked_hashes': [],
        'exception_number': FAULT_VECTOR,
        'flags_mask': hex(FAULT_MASK),
        'records': [record['metadata'] for record in records],
        'source_code_hlt_missing_from_initial_ram': missing_source_hlts,
        'source_code_hlt_missing_count': len(missing_source_hlts),
        'handler_entry_hlt_validated_count': len(records),
        'handler_entry_validation': 'F4 remains unchanged at external final CS:(final IP - 1) in merged captured RAM',
        'vector_sha256': hashlib.sha256(text.encode('ascii')).hexdigest(),
        'revocations': sorted(revoked),
    }
    return text, metadata


def main() -> None:
    hardware.DEST.mkdir(parents=True, exist_ok=True)
    source_bytes, source_artifact = hardware.fetch(SOURCE_PATH)
    revocation_bytes, revocation_artifact = hardware.fetch(REVOCATION_PATH)
    vector_text, manifest = prepare(source_bytes, revocation_bytes)
    manifest['input_artifacts'] = {
        SOURCE_PATH: source_artifact,
        REVOCATION_PATH: revocation_artifact,
    }
    VECTOR_PATH.write_text(vector_text, encoding='ascii')
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f"PASS: imported {manifest['selected_faults']} pinned #GP13 records; "
          f"{manifest['normal_out_of_scope']} normal F7.1 records explicitly out of scope; "
          f"{manifest['selected_revoked']} selected captures revoked")


if __name__ == '__main__':
    main()
