#!/usr/bin/env python3
"""Check physical #GP replay against intact and independently corrupted captures."""

import argparse
from pathlib import Path
import subprocess
import tempfile

from work_paths import get_work_root


REGISTER_COUNT = 14
DEFINED_FLAGS_MASK = 0x7FD7
FAULT_VECTOR = 13


def parse_records(path):
    records = []
    pending = []
    for raw_line in path.read_text(encoding='ascii').splitlines():
        line = raw_line.strip()
        if not line:
            continue
        pending.append(line)
        if line == 'END':
            if len(pending) != 6:
                raise ValueError('Expected six lines in each physical protection capture')
            header = pending[0].split()
            encoding = header[2].lower() if len(header) > 2 else ''
            if (len(header) != 6 or header[0] != 'HWFAULT' or
                    len(encoding) < 2 or len(encoding) % 2 != 0 or
                    any(character not in '0123456789abcdef' for character in encoding) or
                    not encoding.endswith('f4')):
                raise ValueError('Expected a complete physical #GP capture')
            if int(header[3], 16) != 0xF7 or int(header[4], 16) != DEFINED_FLAGS_MASK:
                raise ValueError('Unexpected physical protection opcode or FLAGS mask')
            if int(header[5], 16) != FAULT_VECTOR:
                raise ValueError('Expected physical protection vector 13')
            for index, name in ((1, 'INITIAL'), (2, 'FINAL')):
                words = pending[index].split()
                if words[0] != name or len(words) != REGISTER_COUNT + 1:
                    raise ValueError(f'Malformed {name} register state')
                if any(int(value, 16) > 0xFFFF for value in words[1:]):
                    raise ValueError(f'Invalid {name} register value')
            for index, name in ((3, 'RAM_INITIAL'), (4, 'RAM_FINAL')):
                words = pending[index].split()
                if len(words) < 2 or words[0] != name:
                    raise ValueError(f'Malformed {name} memory map')
                count = int(words[1], 16)
                if len(words) != 2 + 2 * count:
                    raise ValueError(f'Truncated {name} memory map')
                addresses = [int(words[offset], 16) for offset in range(2, len(words), 2)]
                values = [int(words[offset], 16) for offset in range(3, len(words), 2)]
                if (len(set(addresses)) != count or any(a >= 0x1000000 for a in addresses)
                        or any(value > 0xFF for value in values)):
                    raise ValueError(f'Invalid {name} memory entry')
            records.append(pending)
            pending = []
    if pending or not records:
        raise ValueError('Physical protection vector file is empty or truncated')
    return records


def mutate_register(record, state_line, register_index, xor):
    result = record.copy()
    words = result[state_line].split()
    field = register_index + 1
    words[field] = format(int(words[field], 16) ^ xor, 'x')
    result[state_line] = ' '.join(words)
    return result


def mutate_ram_byte(record, address):
    result = record.copy()
    words = result[4].split()
    count = int(words[1], 16)
    for index in range(2, 2 + 2 * count, 2):
        if int(words[index], 16) == address:
            words[index + 1] = format(int(words[index + 1], 16) ^ 1, 'x')
            result[4] = ' '.join(words)
            return result
    raise ValueError(f'Expected saved-frame byte {address:x} missing from RAM_FINAL')


def run(runner, path, lines, timeout):
    path.write_text('\n'.join(lines) + '\n', encoding='ascii')
    return subprocess.run([str(runner), '--hardware', str(path)],
                          capture_output=True, text=True, timeout=timeout)


def main():
    root = Path(__file__).resolve().parents[1]
    work_root = get_work_root(root)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runner', type=Path, default=work_root / 'sim/Vintel_80286')
    parser.add_argument('--vectors', type=Path,
                        default=work_root / 'hardware/protection_vectors.txt')
    parser.add_argument('--timeout', type=int, default=120,
                        help='maximum seconds for each simulator invocation')
    args = parser.parse_args()
    records = parse_records(args.vectors)

    # Verify the whole imported physical corpus before testing comparator sensitivity.
    baseline = subprocess.run([str(args.runner), '--hardware', str(args.vectors)],
                              capture_output=True, text=True, timeout=args.timeout)
    baseline_output = baseline.stdout + baseline.stderr
    expected_summary = (f'PASS: {len(records)} physical Harris-286 captures, '
                        f'{2 * len(records)} stalled/unstalled executions')
    if baseline.returncode or expected_summary not in baseline.stdout:
        raise RuntimeError('Physical protection baseline failed: ' + baseline_output)
    print(f'PASS: {len(records)} physical protection replay baselines')

    sample = records[0]
    initial = [int(value, 16) for value in sample[1].split()[1:]]
    final = [int(value, 16) for value in sample[2].split()[1:]]
    frame_ip_address = initial[10] * 16 + final[4]
    final_ram = sample[4].split()
    final_addresses = {int(final_ram[index], 16)
                       for index in range(2, len(final_ram), 2)}
    if frame_ip_address not in final_addresses or frame_ip_address + 1 not in final_addresses:
        raise ValueError('Captured saved-frame IP bytes are missing from RAM_FINAL')

    mutations = [
        ('final SP', mutate_register(sample, 2, 4, 1), 'physical register 4'),
        ('handler CS', mutate_register(sample, 2, 9, 1),
         'physical exact exception handler entry CS:IP'),
        ('handler IP', mutate_register(sample, 2, 12, 1),
         'physical exact exception handler entry CS:IP'),
        ('defined CF', mutate_register(sample, 2, 13, 1), 'physical FLAGS'),
        ('saved frame IP low byte', mutate_ram_byte(sample, frame_ip_address),
         'physical final RAM mismatch'),
        ('saved frame IP high byte', mutate_ram_byte(sample, frame_ip_address + 1),
         'physical final RAM mismatch'),
    ]

    with tempfile.TemporaryDirectory(prefix='80286-protection-hardware-') as temporary:
        path = Path(temporary) / 'capture.txt'
        for name, corrupted, diagnostic in mutations:
            result = run(args.runner, path, corrupted, args.timeout)
            output = result.stdout + result.stderr
            if (result.returncode == 0 or 'Physical 286 ' not in output or
                    diagnostic not in output):
                raise RuntimeError(f'Undetected or unexpected {name} corruption: {output}')
            print(f'PASS: rejected corrupted physical {name}')

    print(f'PASS: {len(mutations)} independent #GP oracle-corruption checks')


if __name__ == '__main__':
    main()
