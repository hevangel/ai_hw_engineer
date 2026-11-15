#!/usr/bin/env python3
"""Cross-check the reference model's calendar arithmetic against Python's
datetime, an implementation independent of both the model and the RTL.

For many random instants in 2000-2099 (where the Gregorian rule and the
MC146818 two-digit "divisible by 4" leap rule agree), the ten time bytes
are loaded in each data mode (BCD/binary) and hour mode (12/24), the
model's update cycle runs N times, and the bytes must equal the encoding of
datetime + N seconds, including the day of week (Sunday = 1, Table 3).
Alarm don't-care matching is checked on the same samples.

usage: check_calendar.py [SAMPLES] [SEED]
"""
import datetime as dt
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mc146818_model import update_time, alarm_match, B_DM, B_2412  # noqa: E402


def encode(t, binary, h24):
    def e(x):
        return x if binary else ((x // 10) << 4) | (x % 10)
    if h24:
        hr = e(t.hour)
    else:
        h = t.hour % 12
        hr = e(12 if h == 0 else h) | (0x80 if t.hour >= 12 else 0)
    dow = (t.isoweekday() % 7) + 1          # Sunday = 1 ... Saturday = 7
    return [e(t.second), 0, e(t.minute), 0, hr, 0, e(dow), e(t.day),
            e(t.month), e(t.year % 100)]


def main():
    samples = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
    rng = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
    base = dt.datetime(2000, 1, 1)
    span = int((dt.datetime(2099, 12, 31, 23, 0) - base).total_seconds())
    edges = 0
    checked = 0
    for i in range(samples):
        if i % 2:
            t = base + dt.timedelta(seconds=rng.randrange(span))
        else:
            # Bias towards rollovers: last seconds of a random month end,
            # including 28/29 February in leap and common years.
            y = rng.randrange(2000, 2100)
            m = rng.randrange(1, 13)
            nxt = dt.datetime(y + (m == 12), m % 12 + 1, 1)
            t = nxt - dt.timedelta(seconds=rng.randrange(1, 90))
            edges += 1
        n = rng.choice([1, 1, 2, 5, 60, 61, 3600])
        if t.year == 2099 and t + dt.timedelta(seconds=n) >= dt.datetime(2100, 1, 1):
            continue
        for binary in (False, True):
            for h24 in (False, True):
                regb = (B_DM if binary else 0) | (B_2412 if h24 else 0)
                b = encode(t, binary, h24)
                done = 0
                for _ in range(n):
                    b, _, done, _ = update_time(b, regb, done)
                want = encode(t + dt.timedelta(seconds=n), binary, h24)
                got = [b[k] for k in (0, 2, 4, 6, 7, 8, 9)]
                exp = [want[k] for k in (0, 2, 4, 6, 7, 8, 9)]
                if got != exp:
                    print('FAIL', t, '+%ds' % n, 'binary' if binary else 'bcd',
                          '24h' if h24 else '12h',
                          ' '.join('%02X' % x for x in got), '!=',
                          ' '.join('%02X' % x for x in exp))
                    sys.exit(1)
                # Alarm: exact match, don't-care on each byte, and a miss.
                x = list(b)
                x[1], x[3], x[5] = b[0], b[2], b[4]
                assert alarm_match(x)
                for k in (1, 3, 5):
                    y = list(x)
                    y[k] = rng.randrange(0xC0, 0x100)
                    assert alarm_match(y)
                    y[k] = (x[k - 1] + 1) & 0x3F if x[k - 1] != 0x3F else 0
                    assert not alarm_match(y)
                checked += 1
    print('PASS: calendar %d cases (%d near month ends) x 4 modes match datetime'
          % (checked // 4, edges))


if __name__ == '__main__':
    main()
