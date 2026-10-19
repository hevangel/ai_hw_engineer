#!/usr/bin/env python3
"""Independent published-format oracle for observed J13 transitions."""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    expected = bytes.fromhex('00 ff 55 aa a5 5a')
    checksum = 0xff
    for value in expected:
        checksum ^= value
    expected += bytes([checksum])
    rows = list(csv.reader((ROOT / 'work/cassette_edges.csv').open()))
    assert len(rows) == len(expected) * 16, f'Wrong edge count: {len(rows)}'
    times = [float(row[0]) for row in rows]
    levels = [int(row[1]) for row in rows]
    for row in rows:
        expected_voltage = 4.0 / 121 if row[1] == '1' else 0.2 / 121
        assert abs(float(row[3]) - expected_voltage) <= 1e-9, 'Incorrect cassette jack divider voltage'
    cycles = [int(row[2]) for row in rows]
    bits = [value >> index & 1 for value in expected for index in range(7, -1, -1)]
    periods = []
    for index in range(1, len(rows)):
        assert levels[index] == 1 - levels[index - 1], f'Non-alternating edge {index}'
        interval = times[index] - times[index - 1]
        # Counts derived from the original FCD6..FCEB / FED2..FEF5 listing,
        # including taken/untaken branches. The second half is 250 cycles;
        # the next ordinary first half includes three more instruction cycles.
        count = 250 if index % 2 else 253
        if index % 16 == 0:
            count = 258 if index == 96 else 249  # checksum / next data byte
        count += 250 * bits[index // 2]
        assert cycles[index] - cycles[index - 1] == count, (
            f'Edge {index}: expected {count} CPU clocks, '
            f'got {cycles[index] - cycles[index - 1]}')
        # A normal CPU cycle spans 14 master ticks; one extra pair of ticks
        # occurs per scan line. Bound actual time independently of that phase.
        minimum = count * 14 * 69.842
        maximum = minimum + ((count + 64) // 65) * 2 * 69.842
        assert minimum - 0.01 <= interval <= maximum + 0.01, (
            f'Edge {index}: invalid physical time {interval} ns for {count} clocks')
        periods.append(interval / 1000)
    # Second half of every bit provides complete independent byte decoding.
    decoded = bytearray()
    for byte_index in range(len(expected)):
        value = 0
        for bit_index in range(8):
            first = byte_index * 16 + bit_index * 2
            value = value * 2 + (times[first + 1] - times[first] > 375000)
        decoded.append(value)
    assert decoded == expected, f'Wrong byte order/data: {decoded.hex()}'
    print(f'PASS cassette output: {decoded.hex(" ")}; 111 exact firmware cycle counts; '
          f'physical half-cycles {min(periods):.3f}..{max(periods):.3f} us')


if __name__ == '__main__':
    main()
