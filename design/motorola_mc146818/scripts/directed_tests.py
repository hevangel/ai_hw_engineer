#!/usr/bin/env python3
"""Directed tests for the MC146818, with expected values worked out by hand
from the data sheet (ADI-856-R1, page numbers as in mc146818_model.py) and
the assumption ledger in spec/spec.md. They are not produced by the model:
every "R aa ee", "Q", "M" expectation below is a literal.

Writes one script per test into OUTDIR plus OUTDIR/list.txt with
"name fast_shift" per line. run_sim.sh runs each script on the model
(which checks the expectations) and on the RTL (trace compared to the
model).

Timing used in the expectations (32.768 kHz time base, DV=010, FAST_SHIFT 0):
the divider advances 2**7 per tick, so after a divider reset the 1 Hz edge
(bit 21) comes after 2**21 / 2**7 = 16384 ticks (half a second, p.3-714).
UIP rises on that tick, the update happens tBUC = 8 ticks later and UF is
set tUC = 65 ticks after that (Table 6, assumption R4):
  UIP tick 16384, update tick 16392, UF tick 16457.
A tap k of Table 5 has its first rising edge 2**k / 2**7 ticks after a
divider reset and then repeats every 2**(k+1) / 2**7 ticks.
"""
import os
import sys

UIP_T, UPD_T, UF_T = 16384, 16392, 16457
SECOND = 32768


def restart(rs=0x6, dv=0x2):
    """Hold the divider in reset (DV=111) and release it: Table 4."""
    return ['W 0A %02X' % (0x70 | rs), 'W 0A %02X' % ((dv << 4) | rs)]


def load(regb, t, rs=0):
    """SET=1, write bytes, restart the divider (RS=0 unless given, so no
    periodic flags), write B (SET=0)."""
    s = ['W 0B %02X' % (0x80 | regb)]
    s += ['W %02X %02X' % (a, v) for a, v in sorted(t.items())]
    s += restart(rs)
    s += ['W 0B %02X' % regb, 'R 0C']           # clear stale flags
    return s


def one_update(regb, t, exp, name):
    s = ['# %s' % name] + load(regb, t)
    s += ['T %d' % UF_T]
    s += ['R %02X %02X' % (a, v) for a, v in sorted(exp.items())]
    return s


TESTS = {}


def test(fs=0):
    def deco(fn):
        TESTS[fn.__name__] = (fs, fn)
        return fn
    return deco


@test()
def registers_power_on():
    # Default image is all zero (spec R14): VRT=0 so the first read of D
    # reports lost power; the read sets VRT (Figure 8, p.3-715).
    s = ['R 0A 00', 'R 0B 00', 'R 0C 00', 'R 0D 00', 'R 0D 80']
    # C and D are read-only (p.3-709); writes are ignored.
    s += ['W 0C FF', 'R 0C 00', 'W 0D 00', 'R 0D 80']
    # A bit 7 (UIP) read-only; DV=111 holds the divider so UIP stays 0.
    s += ['W 0A FF', 'R 0A 7F', 'W 0A 00', 'R 0A 00']
    # Seconds bit 7 read-only (p.3-709), reads 0 (R13).
    s += ['W 00 FF', 'R 00 7F', 'W 00 80', 'R 00 00']
    # Other time bytes are plain RAM between updates.
    for a in range(1, 10):
        s += ['W %02X A5' % a, 'R %02X A5' % a, 'W %02X 5A' % a, 'R %02X 5A' % a]
    # B: all bits read/write; SET going high clears UIE (p.3-714).
    s += ['W 0B 7F', 'R 0B 7F', 'W 0B FF', 'R 0B EF', 'W 0B FF', 'R 0B FF',
          'W 0B 00', 'R 0B 00']
    # 50 bytes of user RAM 0E-3F (Figure 15).
    for a in range(0x0E, 0x40):
        v = (a * 37 + 11) & 0xFF
        s += ['W %02X %02X' % (a, v)]
    for a in range(0x0E, 0x40):
        s += ['R %02X %02X' % (a, (a * 37 + 11) & 0xFF)]
    s += ['W 0E 00', 'R 0E 00', 'W 0E FF', 'R 0E FF']
    # CE high: no write, bus not driven (p.3-708).
    s += ['WN 0E 55', 'R 0E FF', 'RN 0E', 'WN 0B 7F', 'R 0B 00']
    # Address latch uses AD5-AD0 only: 4E selects 0E.
    s += ['W 4E 12', 'R 0E 12', 'R CE 12']
    s += ['DUMP']
    return s


@test()
def update_cycle_timing():
    # 23:59:58 Saturday 31 Dec 99, BCD 24 h, UIE on.
    t = {0: 0x58, 2: 0x59, 4: 0x23, 6: 0x07, 7: 0x31, 8: 0x12, 9: 0x99}
    s = load(0x12, t)
    s += ['T %d' % (UIP_T - 1), 'R 0A 20', 'T 1', 'R 0A A0', 'R 00 58']
    s += ['T 7', 'R 0A A0', 'R 00 58', 'Q 1']
    # Writes during UIP but before the update are accepted (R5).
    s += ['T 1', 'R 0A A0', 'R 00 59']
    # During the update cycle the time bytes are off the bus: writes lost (R5).
    s += ['W 02 00', 'R 02 59', 'T 64', 'R 0A A0', 'Q 1', 'R 0C 00']
    s += ['T 1', 'R 0A 20', 'Q 0', 'R 0C 90', 'Q 1', 'R 0C 00']
    # Next second: full rollover to 00:00:00 Sunday 01 Jan 00.
    nxt = UIP_T + SECOND
    s += ['T %d' % (nxt - UF_T - 1), 'R 0A 20', 'T 1', 'R 0A A0',
          'T 8', 'T 65', 'R 0A 20']
    s += ['R 00 00', 'R 02 00', 'R 04 00', 'R 06 01', 'R 07 01', 'R 08 01', 'R 09 00']
    # 00:00:00 equals the alarm bytes (still 00): AF as well as UF.
    s += ['R 0C B0', 'DUMP']
    return s


@test()
def write_during_uip():
    t = {0: 0x05, 2: 0x10, 4: 0x08, 6: 0x02, 7: 0x15, 8: 0x06, 9: 0x84}
    s = load(0x02, t)
    s += ['T %d' % UIP_T, 'R 0A A0', 'W 00 30', 'W 02 44', 'T 8', 'R 00 31', 'R 02 44']
    s += ['T 65', 'R 0C 10']
    return s


ROLL = [
    # (name, regb, bytes before, bytes after one update)  -- hand derived
    ('bcd24_midnight_year', 0x02,
     {0: 0x59, 2: 0x59, 4: 0x23, 6: 0x07, 7: 0x31, 8: 0x12, 9: 0x83},
     {0: 0x00, 2: 0x00, 4: 0x00, 6: 0x01, 7: 0x01, 8: 0x01, 9: 0x84}),
    ('bcd24_minute', 0x02, {0: 0x59, 2: 0x09, 4: 0x13, 6: 0x03, 7: 0x09, 8: 0x09, 9: 0x09},
     {0: 0x00, 2: 0x10, 4: 0x13, 6: 0x03, 7: 0x09, 8: 0x09, 9: 0x09}),
    ('bcd24_hour', 0x02, {0: 0x59, 2: 0x59, 4: 0x09, 6: 0x05},
     {0: 0x00, 2: 0x00, 4: 0x10, 6: 0x05}),
    ('bcd_digit_carry', 0x02, {0: 0x39}, {0: 0x40}),
    ('bcd_leap_feb28', 0x02, {0: 0x59, 2: 0x59, 4: 0x23, 6: 0x02, 7: 0x28, 8: 0x02, 9: 0x96},
     {0: 0x00, 2: 0x00, 4: 0x00, 6: 0x03, 7: 0x29, 8: 0x02, 9: 0x96}),
    ('bcd_leap_feb29', 0x02, {0: 0x59, 2: 0x59, 4: 0x23, 6: 0x03, 7: 0x29, 8: 0x02, 9: 0x96},
     {0: 0x00, 2: 0x00, 4: 0x00, 6: 0x04, 7: 0x01, 8: 0x03, 9: 0x96}),
    ('bcd_common_feb28', 0x02, {0: 0x59, 2: 0x59, 4: 0x23, 6: 0x06, 7: 0x28, 8: 0x02, 9: 0x98},
     {0: 0x00, 2: 0x00, 4: 0x00, 6: 0x07, 7: 0x01, 8: 0x03, 9: 0x98}),
    ('bcd_year00_leap', 0x02, {0: 0x59, 2: 0x59, 4: 0x23, 6: 0x02, 7: 0x28, 8: 0x02, 9: 0x00},
     {0: 0x00, 2: 0x00, 4: 0x00, 6: 0x03, 7: 0x29, 8: 0x02, 9: 0x00}),
    ('bcd_30day_month', 0x02, {0: 0x59, 2: 0x59, 4: 0x23, 6: 0x07, 7: 0x30, 8: 0x11, 9: 0x85},
     {0: 0x00, 2: 0x00, 4: 0x00, 6: 0x01, 7: 0x01, 8: 0x12, 9: 0x85}),
    ('bcd_31day_month', 0x02, {0: 0x59, 2: 0x59, 4: 0x23, 6: 0x01, 7: 0x30, 8: 0x07, 9: 0x85},
     {0: 0x00, 2: 0x00, 4: 0x00, 6: 0x02, 7: 0x31, 8: 0x07, 9: 0x85}),
    ('bcd_century', 0x02, {0: 0x59, 2: 0x59, 4: 0x23, 6: 0x05, 7: 0x31, 8: 0x12, 9: 0x99},
     {0: 0x00, 2: 0x00, 4: 0x00, 6: 0x06, 7: 0x01, 8: 0x01, 9: 0x00}),
    ('bcd12_am_to_pm', 0x00, {0: 0x59, 2: 0x59, 4: 0x11, 6: 0x02, 7: 0x10},
     {0: 0x00, 2: 0x00, 4: 0x92, 6: 0x02, 7: 0x10}),
    ('bcd12_12pm_to_1pm', 0x00, {0: 0x59, 2: 0x59, 4: 0x92}, {4: 0x81}),
    ('bcd12_pm_to_am_day', 0x00, {0: 0x59, 2: 0x59, 4: 0x91, 6: 0x02, 7: 0x10, 8: 0x04},
     {0: 0x00, 2: 0x00, 4: 0x12, 6: 0x03, 7: 0x11, 8: 0x04}),
    ('bcd12_12am_to_1am', 0x00, {0: 0x59, 2: 0x59, 4: 0x12}, {4: 0x01}),
    ('bcd12_9am_to_10am', 0x00, {0: 0x59, 2: 0x59, 4: 0x09}, {4: 0x10}),
    ('bin24_midnight', 0x06, {0: 59, 2: 59, 4: 23, 6: 7, 7: 31, 8: 12, 9: 99},
     {0: 0, 2: 0, 4: 0, 6: 1, 7: 1, 8: 1, 9: 0}),
    ('bin24_seconds', 0x06, {0: 0x09}, {0: 0x0A}),
    ('bin_leap_feb28', 0x06, {0: 59, 2: 59, 4: 23, 6: 1, 7: 28, 8: 2, 9: 4},
     {0: 0, 2: 0, 4: 0, 6: 2, 7: 29, 8: 2, 9: 4}),
    ('bin_common_feb28', 0x06, {0: 59, 2: 59, 4: 23, 6: 1, 7: 28, 8: 2, 9: 5},
     {0: 0, 2: 0, 4: 0, 6: 2, 7: 1, 8: 3, 9: 5}),
    ('bin_30day', 0x06, {0: 59, 2: 59, 4: 23, 6: 4, 7: 30, 8: 6, 9: 50},
     {0: 0, 2: 0, 4: 0, 6: 5, 7: 1, 8: 7, 9: 50}),
    ('bin12_am_to_pm', 0x04, {0: 59, 2: 59, 4: 0x0B}, {4: 0x8C}),
    ('bin12_pm_to_am', 0x04, {0: 59, 2: 59, 4: 0x8B, 6: 7, 7: 9, 8: 9, 9: 9},
     {4: 0x0C, 6: 1, 7: 10, 8: 9, 9: 9}),
    ('bin12_12pm_to_1pm', 0x04, {0: 59, 2: 59, 4: 0x8C}, {4: 0x81}),
    # Daylight saving (DSE, p.3-714; R10). 26 April 1987 was a Sunday.
    ('dst_april_last_sunday', 0x03,
     {0: 0x59, 2: 0x59, 4: 0x01, 6: 0x01, 7: 0x26, 8: 0x04, 9: 0x87},
     {0: 0x00, 2: 0x00, 4: 0x03, 6: 0x01, 7: 0x26, 8: 0x04}),
    ('dst_april_12h', 0x01,
     {0: 0x59, 2: 0x59, 4: 0x01, 6: 0x01, 7: 0x24, 8: 0x04, 9: 0x88},
     {0: 0x00, 2: 0x00, 4: 0x03}),
    ('dst_april_not_last', 0x03,
     {0: 0x59, 2: 0x59, 4: 0x01, 6: 0x01, 7: 0x19, 8: 0x04, 9: 0x87},
     {4: 0x02}),
    ('dst_april_not_sunday', 0x03,
     {0: 0x59, 2: 0x59, 4: 0x01, 6: 0x02, 7: 0x27, 8: 0x04, 9: 0x87},
     {4: 0x02}),
    ('dst_disabled', 0x02,
     {0: 0x59, 2: 0x59, 4: 0x01, 6: 0x01, 7: 0x26, 8: 0x04, 9: 0x87},
     {4: 0x02}),
    ('dst_binary_october', 0x07,
     {0: 59, 2: 59, 4: 1, 6: 1, 7: 25, 8: 10, 9: 87},
     {0: 0, 2: 0, 4: 1, 6: 1, 7: 25, 8: 10}),
]


def make_roll(name, regb, before, after):
    def fn():
        return one_update(regb, before, after, name)
    fn.__name__ = 'roll_' + name
    TESTS[fn.__name__] = (0, fn)


for _r in ROLL:
    make_roll(*_r)


@test()
def dst_october_once():
    # 25 October 1987 was a Sunday. First pass of 1:59:59 -> 1:00:00, the
    # second pass (time written back to 1:59:58) goes on to 2:00:00 (R10).
    t = {0: 0x59, 2: 0x59, 4: 0x01, 6: 0x01, 7: 0x25, 8: 0x10, 9: 0x87}
    s = load(0x03, t) + ['T %d' % UF_T, 'R 00 00', 'R 02 00', 'R 04 01']
    s += ['W 00 58', 'W 02 59', 'T %d' % SECOND, 'R 00 59', 'R 04 01',
          'T %d' % SECOND, 'R 00 00', 'R 02 00', 'R 04 02', 'R 07 25']
    return s


@test()
def alarm_interrupts():
    # UF (10h) is set after every update cycle as well (p.3-714); with AIE
    # only, IRQF (80h) comes from AF (20h).
    s = []
    # Exact match: 10:20:29 -> 10:20:30 equals the alarm (p.3-711). AF is
    # set by the update itself, before UF (R2 timing).
    t = {0: 0x29, 1: 0x30, 2: 0x20, 3: 0x20, 4: 0x10, 5: 0x10}
    s += load(0x22, t) + ['T %d' % UPD_T, 'Q 0', 'R 0C A0', 'Q 1', 'T 65', 'R 0C 10']
    # Next second (10:20:31) does not match.
    s += ['T %d' % SECOND, 'R 00 31', 'R 0C 10', 'Q 1']
    # AF sets with AIE clear, IRQ stays released (p.3-714).
    s += load(0x02, t) + ['T %d' % UF_T, 'Q 1', 'R 0C 30']
    # Don't care seconds (FF) and minutes (C0): every second in hour 10.
    t2 = {0: 0x00, 1: 0xFF, 2: 0x00, 3: 0xC0, 4: 0x10, 5: 0x10}
    s += load(0x22, t2) + ['T %d' % UF_T, 'R 0C B0', 'T %d' % SECOND, 'R 0C B0']
    # Don't care in all three: every second.
    t3 = {1: 0xC5, 3: 0xE0, 5: 0xFE, 4: 0x15}
    s += load(0x22, t3) + ['T %d' % UF_T, 'R 0C B0']
    # Hours mismatch (11 vs 10) with don't-care minutes/seconds: no alarm.
    t4 = {0: 0x00, 1: 0xFF, 2: 0x00, 3: 0xFF, 4: 0x10, 5: 0x11}
    s += load(0x22, t4) + ['T %d' % UF_T, 'R 0C 10']
    # 80h-BFh is not a don't-care code: alarm 80 against seconds 01 never hits.
    t5 = {0: 0x00, 1: 0x80, 2: 0x00, 3: 0xC0, 4: 0x10, 5: 0xC0}
    s += load(0x22, t5) + ['T %d' % UF_T, 'R 0C 10']
    # 80h-BFh in the minutes and hours alarms are not don't-care codes either.
    t8 = {0: 0x00, 1: 0xC0, 2: 0x00, 3: 0xA0, 4: 0x10, 5: 0xC0}
    s += load(0x22, t8) + ['T %d' % UF_T, 'R 0C 10']
    t9 = {0: 0x00, 1: 0xC0, 2: 0x00, 3: 0xC0, 4: 0x10, 5: 0x90}
    s += load(0x22, t9) + ['T %d' % UF_T, 'R 0C 10']
    # 12-hour alarm compares the PM bit: alarm 12:00:00 AM (12) vs PM (92).
    t6 = {0: 0x59, 1: 0x00, 2: 0x59, 3: 0x00, 4: 0x11, 5: 0x12}
    s += load(0x20, t6) + ['T %d' % UF_T, 'R 04 92', 'R 0C 10']
    t7 = {0: 0x59, 1: 0x00, 2: 0x59, 3: 0x00, 4: 0x11, 5: 0x92}
    s += load(0x20, t7) + ['T %d' % UF_T, 'R 0C B0']
    return s


@test()
def periodic_rates_32k():
    # Table 5, 32.768 kHz column. tap k: first edge 2**(k-7) ticks after the
    # divider reset, then every 2**(k-6) ticks.
    taps = {1: 13, 2: 14, 3: 8, 4: 9, 5: 10, 6: 11, 7: 12, 8: 13, 9: 14,
            10: 15, 11: 16, 12: 17, 13: 18, 14: 19, 15: 20}
    s = ['W 0B 82']                               # SET, so no update flags
    for rs, k in sorted(taps.items()):
        first, period = 1 << (k - 7), 1 << (k - 6)
        s += ['# RS=%d tap %d first %d period %d' % (rs, k, first, period)]
        s += ['W 0A %02X' % (0x70 | rs), 'R 0C', 'W 0A %02X' % (0x20 | rs)]
        if first > 1:
            s += ['T %d' % (first - 1), 'R 0C 00']
        s += ['T 1', 'R 0C 40', 'T %d' % (period - 1), 'R 0C 00', 'T 1', 'R 0C 40']
    # RS=0: no periodic flag and no square wave.
    s += ['W 0B 8A', 'W 0A 70', 'W 0A 20', 'R 0C', 'T 40000', 'R 0C 00', 'Q 1 0']
    return s


@test()
def periodic_rates_1m_4m():
    # Table 5, 4.194304 / 1.048576 MHz column with DV=000 (step 1) and
    # DV=001 (step 4): RS=1 -> 32.768 kHz.
    s = ['W 0B 82']
    for dv, step in ((0, 1), (1, 4)):
        for rs in (1, 2, 3, 6, 9):
            k = rs + 5
            first, period = (1 << k) // step, (1 << (k + 1)) // step
            s += ['W 0A %02X' % (0x70 | rs), 'R 0C', 'W 0A %02X' % ((dv << 4) | rs)]
            s += ['T %d' % (first - 1), 'R 0C 00', 'T 1', 'R 0C 40',
                  'T %d' % (period - 1), 'R 0C 00', 'T 1', 'R 0C 40']
    return s


@test()
def square_wave_and_pie():
    s = ['W 0B 82', 'W 0A 76', 'W 0A 26', 'R 0C']
    # SQWE=0: SQW low (p.3-714).
    s += ['T 16', 'Q 1 0']
    # RS=6 tap 11: 1.024 kHz, high from tick 16 to 31 of each 32 (R6).
    s += ['W 0B 8A', 'W 0A 76', 'W 0A 26', 'R 0C', 'Q 1 0', 'T 15', 'Q 1 0',
          'T 1', 'Q 1 1', 'T 15', 'Q 1 1', 'T 1', 'Q 1 0']
    # PIE: IRQ low at the PF edge; reading C releases it (p.3-714).
    # PF from tick 16 is still set when PIE is enabled: IRQ at once (p.3-711).
    s += ['W 0B CA', 'Q 0 0', 'R 0C C0', 'Q 1 0', 'T 16', 'Q 0 1', 'R 0C C0', 'Q 1 1']
    # Clearing PIE with PF still set releases IRQ; IRQF reads 0 (R11).
    s += ['T 32', 'Q 0 1', 'W 0B 8A', 'Q 1 1', 'R 0C 40']
    # PIE with a flag already set asserts IRQ immediately (p.3-711).
    s += ['T 32', 'W 0B CA', 'Q 0 1', 'R 0C C0']
    s += ['W 0B 82', 'Q 1 0']
    return s


@test()
def set_bit_behaviour():
    t = {0: 0x10, 2: 0x20, 4: 0x05}
    s = load(0x12, t, rs=6)
    # SET during UIP aborts the update and clears UIP (p.3-713/714); it also
    # clears UIE.
    s += ['T %d' % UIP_T, 'R 0A A6', 'W 0B 92', 'R 0A 26', 'R 0B 82']
    s += ['T 40000', 'R 00 10', 'R 0A 26', 'Q 1']
    # Periodic flags still occur while SET is 1 (p.3-711).
    s += ['R 0C 40']
    # Clearing SET: updates resume on the next 1 Hz edge.
    tick_now = UIP_T + 40000
    nxt = UIP_T + 2 * SECOND
    s += ['W 0B 02', 'T %d' % (nxt - tick_now - 1), 'R 0A 26', 'T 1', 'R 0A A6',
          'T 8', 'R 00 11']
    # SET written during the update cycle aborts it: no UF.
    s += ['W 0B 82', 'R 0A 26', 'T 100', 'R 0C 40']
    return s


@test()
def reset_pin():
    t = {0: 0x10, 2: 0x20, 4: 0x05, 0x20: 0x5A}
    s = load(0x7F & ~0x80, t, rs=6)               # PIE AIE UIE SQWE DM 24 DSE
    s += ['T 100', 'Q 0']                          # PF set by now, PIE on
    s += ['RST 0', 'Q 1 0', 'R 0B', 'R 0C', 'W 20 00', 'RST 1']
    # Only the enables and flags were cleared (p.3-708/709).
    s += ['R 0B 07', 'R 0C 00', 'R 0A 26', 'R 00 10', 'R 20 5A', 'Q 1 0']
    # RESET does not affect UIP or the update (p.3-713): assert it across
    # the UIP window and the update still happens. Divider is still running
    # from the restart in load(): tick count is UF_T... use a fresh restart.
    s += ['W 0B 06'] + restart() + ['T %d' % UIP_T, 'R 0A A6', 'RST 0', 'T 8', 'RST 1',
                                    'R 0A A6', 'R 00 11', 'T 65', 'R 0A 26',
                                    # PF (every 32 ticks) and UF; enables are 0
                                    'R 0C 50']
    # Flags cannot set while RESET is low.
    s += ['W 0B 46', 'RST 0', 'T 64', 'RST 1', 'R 0C 00', 'Q 1']
    return s


@test()
def vrt_and_ps():
    s = ['R 0D 00', 'R 0D 80', 'PS 0', 'R 0D 00', 'R 0D 00', 'PS 1', 'R 0D 00',
         'R 0D 80', 'R 0D 80', 'PS 0', 'PS 1', 'R 0D 00', 'R 0D 80']
    return s


@test()
def regc_flags_and_irqf():
    t = {0: 0x29, 1: 0x30, 2: 0x20, 3: 0x20, 4: 0x10, 5: 0x10}
    s = load(0x22, t, rs=6)                         # AIE only
    s += ['T %d' % UF_T]
    # PF, AF, UF all set; IRQF from AF.AIE (p.3-714).
    s += ['R 0C F0', 'R 0C 00']
    s += ['W 0B 02', 'T %d' % SECOND, 'R 0C 50', 'T 32', 'W 0B 42', 'Q 0', 'R 0C C0']
    return s


@test()
def divider_test_codes():
    # DV=011/100/101 (test codes, R3) behave like a held divider.
    s = ['W 0B 0A']
    for dv in (3, 4, 5, 6, 7):
        s += ['W 0A %02X' % ((dv << 4) | 6), 'R 0C', 'T 40000', 'R 0C 00',
              'R 0A %02X' % ((dv << 4) | 6), 'Q 1 0']
    # Back to 010: first update half a second later (p.3-714).
    s += ['W 0A 26', 'T %d' % (UIP_T - 1), 'R 0A 26', 'T 1', 'R 0A A6']
    # Switching to reset during UIP aborts the update.
    s += ['W 0A 76', 'R 0A 76', 'W 0A 26', 'R 0A 26']
    return s


@test(fs=6)
def fast_uip_window_4m():
    # DV=000 with FAST_SHIFT 6: step 2**6, second = 65536 ticks, first edge
    # after 32768; tBUC = 1024/64 = 16 ticks, tUC = ceil(1040/64) = 17 ticks.
    s = ['W 0B 82', 'W 00 00', 'W 0A 70', 'W 0A 00', 'W 0B 12', 'R 0C']
    s += ['T 32767', 'R 0A 00', 'T 1', 'R 0A 80', 'T 15', 'R 00 00', 'T 1', 'R 00 01',
          'T 16', 'R 0A 80', 'Q 1', 'T 1', 'R 0A 00', 'Q 0']
    return s


@test(fs=6)
def fast_uip_window_1m():
    # DV=001: step 2**8, second = 16384 ticks, first edge after 8192;
    # tBUC = 256/64 = 4 ticks, tUC = ceil(260/64) = 5 ticks.
    s = ['W 0B 82', 'W 00 00', 'W 0A 70', 'W 0A 10', 'W 0B 12', 'R 0C']
    s += ['T 8191', 'R 0A 10', 'T 1', 'R 0A 90', 'T 3', 'R 00 00', 'T 1', 'R 00 01',
          'T 4', 'R 0A 90', 'T 1', 'R 0A 10', 'R 0C 90']
    return s


@test(fs=6)
def fast_uip_window_32k():
    # DV=010: step 2**13, second = 512 ticks, first edge after 256;
    # tBUC = ceil(8/64) = 1 tick, tUC = ceil(65/64) = 2 ticks.
    s = ['W 0B 82', 'W 00 00', 'W 0A 70', 'W 0A 20', 'W 0B 12', 'R 0C']
    s += ['T 255', 'R 0A 20', 'T 1', 'R 0A A0', 'R 00 00', 'T 1', 'R 00 01',
          'R 0A A0', 'T 1', 'R 0A A0', 'T 1', 'R 0A 20', 'R 0C 90',
          'T 508', 'R 0A 20', 'T 1', 'R 0A A0']
    return s


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, 'list.txt'), 'w') as lst:
        for name, (fs, fn) in TESTS.items():
            with open(os.path.join(out, name + '.txt'), 'w') as f:
                f.write('\n'.join(fn()) + '\n')
            lst.write('%s %d\n' % (name, fs))
    print('wrote %d directed tests' % len(TESTS))


if __name__ == '__main__':
    main()
