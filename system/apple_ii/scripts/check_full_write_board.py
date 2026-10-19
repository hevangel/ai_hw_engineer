#!/usr/bin/env python3
"""Original Monitor listing cycle oracle applied to physical J13 samples."""
import csv
from pathlib import Path

rows = list(csv.reader((Path(__file__).resolve().parents[1]/'work/full_cassette_board.csv').open()))
assert len(rows) == 16499, f'Full physical WRITE edge count {len(rows)}'
start = len(rows)-112
expected = bytes.fromhex('00 ff 55 aa a5 5a 00')
for i, row in enumerate(rows):
    voltage = (4 if row[1] == '1' else .2)/121
    assert abs(float(row[3])-voltage) < 1e-9, 'Physical R18/R19 voltage'
    if not i:
        continue
    assert int(row[1]) == 1-int(rows[i-1][1]), 'Non-alternating J13 output'
    if i < start-2:
        count = 656 if (i-1) % 256 == 0 else 652
    elif i == start-2:
        count = 195
    elif i == start-1:
        count = 250
    elif i == start:
        count = 252
    else:
        n = i-start
        count = 250 if n % 2 else 253
        if n % 16 == 0:
            count = 258 if n == 96 else 249+(4 if n == 48 else 0)
        count += 250*(expected[n//16] >> (7-(n % 16)//2) & 1)
    actual = int(row[2])-int(rows[i-1][2])
    assert actual == count, f'Physical edge {i}: {actual} clocks, expected {count}'
    interval = float(row[0])-float(rows[i-1][0])
    minimum = count*14*69.842
    maximum = minimum+((count+64)//65)*2*69.842
    assert minimum-.01 <= interval <= maximum+.01, f'Physical edge time {i}'
assert float(rows[start][0])-float(rows[0][0]) > 10e9, 'Truncated leader'
print('PASS full physical WRITE: 16499 transitions, 16498 exact intervals, real jack voltage and unmodified 10-second leader')
