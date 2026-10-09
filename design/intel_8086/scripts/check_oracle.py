#!/usr/bin/env python3
"""Negative controls: exact-IP and bus-write failures must be detected."""
from pathlib import Path
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
data = (ROOT / 'work/vectors.bin').read_bytes()
position = 8
while position < len(data):
    start = position
    label_length = struct.unpack_from('<H', data, position)[0]
    position += 2 + label_length
    expected_ip = position + 28 + 24
    position += 28 + 28 + 2
    for _ in range(2):
        count = struct.unpack_from('<I', data, position)[0]
        position += 4 + count * 5
    write_count_position = position
    count = struct.unpack_from('<I', data, position)[0]
    position += 4 + count * 5
    if count:
        break
else:
    raise RuntimeError('No hardware memory-writing fixture for negative controls')

record = bytearray(data[start:position])
path = ROOT / 'work/oracle_control.bin'
runner = ROOT / 'work/verilator/Vintel_8086'


def run(payload, expected_failure):
    path.write_bytes(data[:8] + payload)
    result = subprocess.run([str(runner), '--vectors', str(path)], capture_output=True, text=True)
    if expected_failure is None:
        if result.returncode:
            raise RuntimeError('Unmodified control failed: ' + result.stderr)
    elif result.returncode == 0 or expected_failure not in result.stderr:
        raise RuntimeError('Oracle did not reject mutation: ' + result.stdout + result.stderr)


run(record, None)
bad_ip = bytearray(record)
bad_ip[expected_ip - start] ^= 1
run(bad_ip, 'IP actual=')
missing_writes = bytearray(record[:write_count_position-start]) + struct.pack('<I', 0)
run(missing_writes, 'ordered byte writes differ')
print('PASS: oracle negative controls reject incorrect next IP and extra writes')
