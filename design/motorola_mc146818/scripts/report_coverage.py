#!/usr/bin/env python3
"""Summarize model coverage counters from the random seeds.

usage: report_coverage.py COV.json... [--require]

Prints which registers were written/read, which register-bit values were
written, which interrupt sources fired (flag set and IRQ asserted) and
which rollovers happened. With --require, exits 1 if any item in the
required list was never exercised.
"""
import json
import sys

REQUIRED = [
    'pf_set', 'af_set', 'uf_set', 'irq_pf', 'irq_af', 'irq_uf', 'uip_set',
    'regc_clear', 'vrt_set', 'set_rising', 'update_aborted', 'reset_pin', 'ps_low',
    'write_during_uip', 'write_lost_in_update', 'write_readonly',
    'second_skipped_by_set',
    'roll_sec', 'roll_min', 'roll_day', 'roll_month', 'roll_year',
    'roll_am_pm', 'roll_pm_am', 'reach_feb29', 'roll_leap_day_end',
    'roll_feb28_nonleap', 'dst_spring', 'dst_fall',
]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    total = {}
    for f in args:
        for k, v in json.load(open(f)).items():
            total[k] = total.get(k, 0) + v
    w = sorted(int(k[6:], 16) for k in total if k.startswith('write_') and len(k) == 8)
    rd = sorted(int(k[5:], 16) for k in total if k.startswith('read_'))
    print('locations written: %d of 64; read: %d of 64' % (len(w), len(rd)))
    missing_bits = []
    for a in (0x0A, 0x0B):
        for b in range(8):
            for v in (0, 1):
                if not total.get('wbit_%02X_%d_%d' % (a, b, v)):
                    missing_bits.append('%02X.%d=%d' % (a, b, v))
    nb = sum(1 for k in total if k.startswith('wbit_'))
    print('register bit values written (location.bit=value): %d of 1024 overall;'
          ' registers A/B all 32: %s' % (nb, 'yes' if not missing_bits else
                                         'missing ' + ' '.join(missing_bits)))
    rs = sorted(int(k[5:]) for k in total if k.startswith('pf_rs'))
    print('periodic flag seen for RS values: %s' % ' '.join(map(str, rs)))
    for k in REQUIRED:
        print('  %-24s %d' % (k, total.get(k, 0)))
    missing = [k for k in REQUIRED if not total.get(k)]
    bad = missing or missing_bits or len(w) < 64 or len(rd) < 64
    if '--require' in sys.argv and bad:
        print('FAIL: coverage holes:', ' '.join(missing))
        sys.exit(1)
    print('PASS: coverage' if not bad else 'NOTE: coverage holes')


if __name__ == '__main__':
    main()
