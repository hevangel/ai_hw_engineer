#!/usr/bin/env python3
"""Check replay sensitivity by corrupting a captured oracle, never the RTL."""
import argparse
from pathlib import Path
import subprocess
import tempfile

from work_paths import get_work_root


def main():
    root = Path(__file__).resolve().parents[1]
    work_root = get_work_root(root)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runner', type=Path, default=work_root / 'sim/Vintel_80286')
    parser.add_argument('--vectors', type=Path, default=work_root / 'hardware/vectors.txt')
    args = parser.parse_args()
    samples = {}
    with args.vectors.open() as source:
        record = []
        for line in source:
            record.append(line.rstrip('\n'))
            if line.strip() == 'END':
                if len(record) != 6 or record[0].split()[0] != 'HWCASE':
                    raise ValueError('Expected a complete physical capture')
                opcode = int(record[0].split()[3], 16)
                samples.setdefault(opcode, record)
                record = []
    arithmetic = (0x14, 0x15, 0x1c, 0x1d, 0x2c, 0x2d, 0x3c, 0x3d)
    if record or not {0x04, 0x05, 0xf6, 0xf7, *arithmetic, *range(0x40, 0x50)} <= samples.keys():
        raise ValueError('Physical sensitivity corpus missing required opcode samples')
    record = samples[0x04]

    def changed(line, field, xor, base=record):
        result = base.copy()
        words = result[line].split()
        words[field] = format(int(words[field], 16) ^ xor, 'x')
        result[line] = ' '.join(words)
        return result

    mutations = [
        ('AX', changed(2, 1, 1), 'physical register 0'),
        ('preserved CX', changed(2, 2, 1), 'physical register 1'),
        ('DS', changed(2, 12, 1), 'physical segment-register mismatch'),
        ('carry flag', changed(2, 14, 1), 'physical FLAGS'),
        ('overflow flag', changed(2, 14, 0x800), 'physical FLAGS'),
        ('final IP', changed(2, 13, 1), 'physical non-flow final PC accounting mismatch'),
        ('final RAM', changed(4, 3, 1), 'physical final RAM mismatch'),
    ]
    # Corrupt the captured HLT byte in initial RAM, leaving the expected code
    # and final state intact. This tests execution of the exact successor.
    halt = record.copy()
    words = halt[3].split()
    initial = record[1].split()
    final = record[2].split()
    halt_address = int(initial[10], 16) * 16 + int(final[13], 16) - 1
    for field in range(2, len(words), 2):
        if int(words[field], 16) == halt_address:
            words[field + 1] = '90'
            break
    else:
        raise ValueError('Captured HLT missing from initial RAM')
    halt[3] = ' '.join(words)
    mutations.append(('HLT successor', halt, ''))
    for opcode in arithmetic:
        sample = samples[opcode]
        name = f'opcode {opcode:02X}'
        mutations.extend([
            (name + ' accumulator', changed(2, 1, 1, sample), 'physical register 0'),
            (name + ' CF', changed(2, 14, 1, sample), 'physical FLAGS'),
            (name + ' OF', changed(2, 14, 0x800, sample), 'physical FLAGS'),
        ])
        if opcode in (0x14, 0x15, 0x1c, 0x1d):
            mutations.append((name + ' initial carry input', changed(1, 14, 1, sample),
                              'physical register 0'))
    for opcode in range(0x40, 0x50):
        sample = samples[opcode]
        reg = opcode & 7
        name = ('INC' if opcode < 0x48 else 'DEC') + ' ' + (
            'AX', 'CX', 'DX', 'BX', 'SP', 'BP', 'SI', 'DI')[reg]
        mutations.extend([
            (name + ' result', changed(2, reg + 1, 1, sample), f'physical register {reg}'),
            (name + ' preserved CF', changed(2, 14, 1, sample), 'physical FLAGS'),
        ])
    for opcode in (0xf6, 0xf7):
        sample = samples[opcode]
        name = f'TEST alias {opcode:02X}'
        mutations.extend([
            (name + ' preserved AX', changed(2, 1, 1, sample), 'physical register 0'),
            (name + ' CF', changed(2, 14, 1, sample), 'physical FLAGS'),
            (name + ' OF', changed(2, 14, 0x800, sample), 'physical FLAGS'),
        ])

    with tempfile.TemporaryDirectory(prefix='80286-hardware-') as temporary:
        path = Path(temporary) / 'capture.txt'

        def run(lines):
            path.write_text('\n'.join(lines) + '\n')
            return subprocess.run([str(args.runner), '--hardware', str(path)],
                                  capture_output=True, text=True, timeout=30)

        for opcode, sample in sorted(samples.items()):
            baseline = run(sample)
            if baseline.returncode or 'PASS: 1 physical Harris-286 captures' not in baseline.stdout:
                raise RuntimeError(f'Physical baseline {opcode:02x} failed: ' + baseline.stdout + baseline.stderr)
        for name, lines, diagnostic in mutations:
            result = run(lines)
            output = result.stdout + result.stderr
            if result.returncode == 0 or 'Physical 286 ' not in output or diagnostic not in output:
                raise RuntimeError(f'Undetected or unexpected {name} corruption: {output}')
            print(f'PASS: rejected corrupted physical {name}')
        for opcode in (0xf6, 0xf7):
            result = run(changed(2, 14, 0x10, samples[opcode]))
            if result.returncode or 'PASS:' not in result.stdout:
                raise RuntimeError(f'Undefined AF incorrectly compared for alias {opcode:02X}')
            print(f'PASS: TEST alias {opcode:02X} excludes only undefined AF from the flag mask')
    print(f'PASS: {len(samples)} physical replay baselines and {len(mutations)} oracle-corruption checks')


if __name__ == '__main__':
    main()
