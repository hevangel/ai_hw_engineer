#!/usr/bin/env python3
"""Reference model of the Motorola MC146818 real-time clock plus RAM.

Written from the Motorola data sheet "MC146818 Real-Time Clock plus RAM
(RTC)", Advance Information ADI-856-R1, as printed in the Motorola 1983
"8-Bit Microprocessor and Peripheral Data" book (pages 3-697 to 3-718).
Page references below ("p.3-7xx") are to that printing. The model is not
derived from the RTL. Behavior the data sheet leaves open is tagged
"ASSUMPTION Rn"; the same tags appear in the RTL and in spec/spec.md.

The model is cycle-free: each bus operation is atomic, and time advances
in oscillator ticks (one OSC1 period each; with FAST_SHIFT = s one tick
stands for 2**s oscillator periods).

Command-line use (lockstep partner of tb/mc146818_tb.cpp):

    mc146818_model.py SCRIPT TRACE_OUT [--fast-shift S] [--nvram FILE]
                      [--coverage COVFILE]

runs the script (format in tb/mc146818_tb.cpp), writes the trace, and checks
every expectation written in the script. Exit status 1 on a failed
expectation.
"""
import argparse
import json
import sys

DIV_BITS = 22            # 22 binary divider stages (p.3-711)
DIV_MASK = (1 << DIV_BITS) - 1
SEC_BIT = 21             # output of the last stage: the 1 Hz update clock

# Table 4 (p.3-712): DV2..DV0 -> number of bypassed first divider stages N.
# 11x holds the divider in reset. Other codes are "test purposes only".
DV_BYPASS = {0b000: 0, 0b001: 2, 0b010: 7}

# Table 6 (p.3-713) in oscillator periods for each time base.
# tBUC = 244 us; tUC = 248 us (4.194304/1.048576 MHz) or 1984 us (32.768 kHz).
# ASSUMPTION R4: both are rounded to whole oscillator periods:
#   32.768 kHz: 8 (244.1 us) and 65 (1983.6 us)
#   1.048576 MHz: 256 (244.1 us) and 260 (248.0 us)
#   4.194304 MHz: 1024 (244.1 us) and 1040 (248.0 us)
T_BUC = {0: 1024, 2: 256, 7: 8}
T_UC = {0: 1040, 2: 260, 7: 65}

REG_A, REG_B, REG_C, REG_D = 0x0A, 0x0B, 0x0C, 0x0D
B_SET, B_PIE, B_AIE, B_UIE, B_SQWE, B_DM, B_2412, B_DSE = (
    0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01)


def tap_bit(rs, dv):
    """Divider bit that RS3..RS0 select (Table 5, p.3-712).

    Bit k of the 22-bit divider (counting in 4.194304 MHz periods) toggles
    at 2**22 / 2**(k+1) Hz. Table 5 gives RS=1 -> 32.768 kHz (bit 6) and
    each further RS step halves the frequency, so tap = RS + 5. With the
    32.768 kHz time base, RS=1 and RS=2 give 256 Hz and 128 Hz, the same as
    RS=8 and RS=9 (bits 13 and 14). Returns None for RS=0 (no output).
    """
    if rs == 0:
        return None
    if dv == 0b010 and rs in (1, 2):
        return rs + 12
    return rs + 5


def bcd_inc(v):
    """Increment a packed-BCD byte. ASSUMPTION R7: a low digit of 9 or more
    carries into the high digit; the high digit wraps modulo 16."""
    if (v & 0x0F) >= 9:
        return (((v >> 4) + 1) & 0x0F) << 4
    return (v + 1) & 0xFF


class MC146818:
    def __init__(self, image=None, fast_shift=0):
        assert 0 <= fast_shift <= 10
        self.fs = fast_shift
        img = list(image) if image else [0] * 64
        assert len(img) == 64
        # 64 locations (Figure 15, p.3-710). Index 0..9 time/alarm bytes,
        # 0x0E..0x3F user RAM. A[6:0] and B live here; UIP, the C flags and
        # VRT are kept separately but initialized from the image
        # (ASSUMPTION R14).
        self.mem = [b & 0xFF for b in img]
        self.mem[0] &= 0x7F                 # seconds bit 7 is read-only (p.3-709)
        self.mem[REG_A] &= 0x7F             # UIP is read-only
        self.pf = (img[REG_C] >> 6) & 1
        self.af = (img[REG_C] >> 5) & 1
        self.uf = (img[REG_C] >> 4) & 1
        self.vrt = (img[REG_D] >> 7) & 1
        # Internal state cleared at power-on (rst_n): ASSUMPTION R14.
        self.addr = 0
        self.div = 0
        self.seq = 'idle'                   # idle / buc (UIP, before update) / uc (update cycle)
        self.cnt = 0
        self.dst_done = 0                   # October fall-back already applied (R10)
        self.reset_low = False              # RESET pin level
        self.ps = 1                         # PS pin level
        self.ticks = 0
        self.cov = {}

    # ---------------------------------------------------------------- helpers
    def _c(self, key, n=1):
        self.cov[key] = self.cov.get(key, 0) + n

    @property
    def regb(self):
        return self.mem[REG_B]

    @property
    def dv(self):
        return (self.mem[REG_A] >> 4) & 7

    @property
    def rs(self):
        return self.mem[REG_A] & 0x0F

    def uip(self):
        return 1 if self.seq != 'idle' else 0

    def irqf(self):
        b = self.regb
        return 1 if ((self.pf and b & B_PIE) or (self.af and b & B_AIE)
                     or (self.uf and b & B_UIE)) else 0

    def irq_n(self):
        """IRQ pin: 0 = driven low, 1 = high impedance (p.3-708)."""
        return 0 if self.irqf() else 1

    def sqw(self):
        """SQW pin (p.3-708, SQWE p.3-714): selected tap when SQWE=1, else low."""
        if not self.regb & B_SQWE:
            return 0
        if self.dv not in DV_BYPASS:
            return 0
        k = tap_bit(self.rs, self.dv)
        if k is None:
            return 0
        return (self.div >> k) & 1

    def view(self, a):
        """Architectural value of location a without side effects."""
        if a == 0:
            return self.mem[0] & 0x7F
        if a == REG_A:
            return (self.uip() << 7) | (self.mem[REG_A] & 0x7F)
        if a == REG_C:
            return (self.irqf() << 7) | (self.pf << 6) | (self.af << 5) | (self.uf << 4)
        if a == REG_D:
            return self.vrt << 7
        return self.mem[a]

    def _abort_update(self):
        if self.seq != 'idle':
            self._c('update_aborted')
        self.seq = 'idle'
        self.cnt = 0

    # ---------------------------------------------------------------- pins
    def set_reset(self, level):
        """RESET pin (p.3-708/709). Low: PIE, AIE, UIE, SQWE, PF, AF, UF
        cleared, IRQ released, part not accessible. Time, RAM, SET, DM,
        24/12, DSE, DV, RS and UIP untouched."""
        self.reset_low = not level
        if self.reset_low:
            self._c('reset_pin')
            self._apply_reset()

    def _apply_reset(self):
        self.mem[REG_B] &= ~(B_PIE | B_AIE | B_UIE | B_SQWE) & 0xFF
        self.pf = self.af = self.uf = 0

    def set_ps(self, level):
        """PS pin (p.3-709): low clears VRT."""
        self.ps = 1 if level else 0
        if not self.ps:
            self._c('ps_low')
            self.vrt = 0

    # ---------------------------------------------------------------- bus
    def addr_strobe(self, ad, ce=True):
        """Falling edge of AS latches AD0-AD5 (p.3-708). ASSUMPTION R1: no
        latch while CE is high or RESET is low."""
        if ce and not self.reset_low:
            self.addr = ad & 0x3F

    def read(self, ce=True):
        """Data strobe read cycle; returns the byte, or None when the bus is
        not driven (CE high or RESET low)."""
        if not ce or self.reset_low:
            return None
        a = self.addr
        v = self.view(a)
        self._c('read_%02X' % a)
        if a == REG_C:
            # Clear-on-read (p.3-711, p.3-714): the flags that read as 1 are
            # cleared at the end of the read cycle.
            if self.pf or self.af or self.uf:
                self._c('regc_clear')
            self.pf = self.af = self.uf = 0
        elif a == REG_D:
            # ASSUMPTION R12: the read returns the old VRT; the read sets VRT
            # (Figure 8 note, p.3-705; p.3-715) unless PS is low.
            if self.ps:
                if not self.vrt:
                    self._c('vrt_set')
                self.vrt = 1
        return v

    def write(self, v, ce=True):
        if not ce or self.reset_low:
            return
        a = self.addr
        v &= 0xFF
        self._c('write_%02X' % a)
        for bit in range(8):
            self._c('wbit_%02X_%d_%d' % (a, bit, (v >> bit) & 1))
        if a <= 9:
            if self.seq == 'uc':
                # ASSUMPTION R5: time/calendar/alarm bytes are off the bus for
                # the whole update cycle (p.3-713), so writes are lost.
                self._c('write_lost_in_update')
                return
            if self.seq == 'buc':
                self._c('write_during_uip')
            self.mem[a] = v & 0x7F if a == 0 else v
        elif a == REG_A:
            self.mem[REG_A] = v & 0x7F                  # UIP read-only
            if self.dv not in DV_BYPASS:
                # Divider held in reset (Table 4); first update 0.5 s after
                # release (p.3-711, p.3-714).
                self.div = 0
                self._abort_update()
        elif a == REG_B:
            old = self.mem[REG_B]
            if v & B_SET and not old & B_SET:
                # SET going high aborts any update in progress and clears UIP
                # (p.3-713, p.3-714) and clears UIE (p.3-714).
                v &= ~B_UIE & 0xFF
                self._c('set_rising')
                self._abort_update()
            self.mem[REG_B] = v
        elif a in (REG_C, REG_D):
            self._c('write_readonly')                   # read-only (p.3-709)
        else:
            self.mem[a] = v

    # ---------------------------------------------------------------- time
    def tick(self):
        """One tick_i pulse."""
        self.ticks += 1
        dv = self.dv
        if dv not in DV_BYPASS:
            # ASSUMPTION R3: test codes 011, 100, 101 behave like 11x.
            self.div = 0
            if self.seq != 'idle':
                self._abort_update()
            if self.reset_low:
                self._apply_reset()
            return
        n = DV_BYPASS[dv]
        step = 1 << (n + self.fs)
        nd = (self.div + step) & DIV_MASK
        k = tap_bit(self.rs, dv)
        pf_edge = k is not None and not (self.div >> k) & 1 and (nd >> k) & 1
        sec_edge = not (self.div >> SEC_BIT) & 1 and (nd >> SEC_BIT) & 1
        self.div = nd
        stepc = 1 << self.fs
        set_bit = self.regb & B_SET
        prev = self.seq
        if prev == 'buc':
            if self.cnt <= stepc:
                self._do_update()
                self.seq = 'uc'
                self.cnt = T_UC[n]
            else:
                self.cnt -= stepc
        elif prev == 'uc':
            if self.cnt <= stepc:
                self.seq = 'idle'
                self.uf = 1
                self._c('uf_set')
            else:
                self.cnt -= stepc
        elif sec_edge and not set_bit:
            # ASSUMPTION R2: UIP rises on the 1 Hz divider edge and the update
            # starts tBUC later (Figure 16, Table 6).
            self.seq = 'buc'
            self.cnt = T_BUC[n]
            self._c('uip_set')
        if sec_edge and set_bit:
            self._c('second_skipped_by_set')
        if pf_edge:
            # PF set on the selected tap's rising edge (ASSUMPTION R6).
            self.pf = 1
            self._c('pf_set')
            self._c('pf_rs%d' % self.rs)
        if self.reset_low:
            self._apply_reset()
        if self.irqf():
            b = self.regb
            if self.pf and b & B_PIE:
                self._c('irq_pf')
            if self.af and b & B_AIE:
                self._c('irq_af')
            if self.uf and b & B_UIE:
                self._c('irq_uf')

    def _do_update(self):
        t, af, self.dst_done, ev = update_time(
            self.mem[0:10], self.regb, self.dst_done)
        self.mem[0:10] = t
        for e in ev:
            self._c(e)
        if af:
            self.af = 1
            self._c('af_set')


# -------------------------------------------------------------------- calendar
def update_time(t, regb, dst_done):
    """One update cycle on the ten time/alarm bytes t[0..9] (Table 3,
    p.3-710; UPDATE CYCLE p.3-713). Returns (bytes, alarm_hit, dst_done,
    events)."""
    t = list(t)
    binary = bool(regb & B_DM)
    h24 = bool(regb & B_2412)
    dse = bool(regb & B_DSE)
    ev = []

    def enc(x):                         # decimal -> current data mode
        return x if binary else ((x // 10) << 4) | (x % 10)

    def inc(v):
        return (v + 1) & 0xFF if binary else bcd_inc(v)

    def step(v, last, first):
        # ASSUMPTION R7: a byte rolls over when it is >= its last legal
        # value (unsigned byte compare in the current mode).
        if v >= enc(last):
            return enc(first), True
        return inc(v), False

    sec, mnt, hr = t[0] & 0x7F, t[2], t[4]
    dow, date, mon, yr = t[6], t[7], t[8], t[9]

    # Daylight savings (DSE, p.3-714). ASSUMPTION R10: evaluated on the
    # bytes before the increment; "last Sunday" = day-of-week 1 and date in
    # the last seven days (April >= 24, October >= 25).
    at_15959 = sec == enc(59) and mnt == enc(59) and hr == 0x01
    if dse and at_15959 and dow == 1 and mon == enc(4) and date >= enc(24):
        t[0], t[2], t[4] = 0, 0, 0x03
        ev.append('dst_spring')
        return t, alarm_match(t), dst_done, ev
    if (dse and at_15959 and dow == 1 and mon == enc(10) and date >= enc(25)
            and not dst_done):
        t[0], t[2], t[4] = 0, 0, 0x01
        ev.append('dst_fall')
        return t, alarm_match(t), 1, ev

    sec, c = step(sec, 59, 0)
    if c:
        ev.append('roll_sec')
        mnt, c = step(mnt, 59, 0)
        if c:
            ev.append('roll_min')
            if h24:
                hr, c = step(hr, 23, 0)
            else:
                pm = hr & 0x80
                h = hr & 0x7F
                c = False
                if h >= enc(12):
                    h = enc(1)
                elif h == enc(11):
                    h = enc(12)
                    if pm:
                        c = True
                        ev.append('roll_pm_am')
                    else:
                        ev.append('roll_am_pm')
                    pm ^= 0x80
                else:
                    h = inc(h) & 0x7F
                hr = pm | h
            if c:
                ev.append('roll_day')
                dow, _ = step(dow, 7, 1)
                dim = days_in_month(mon, yr, binary)
                if date == enc(29) and mon == enc(2):
                    ev.append('roll_leap_day_end')
                if date == enc(28) and mon == enc(2) and dim == enc(28):
                    ev.append('roll_feb28_nonleap')
                if date == enc(28) and mon == enc(2) and dim == enc(29):
                    ev.append('reach_feb29')
                # Date rolls over at the end of the month (same >= rule, R7).
                if date >= dim:
                    date, c = enc(1), True
                else:
                    date, c = inc(date), False
                if c:
                    ev.append('roll_month')
                    mon, c = step(mon, 12, 1)
                    if c:
                        ev.append('roll_year')
                        yr, c = step(yr, 99, 0)
                        if c:
                            ev.append('roll_century')
    if hr != 0x01:
        dst_done = 0
    t[0], t[2], t[4], t[6], t[7], t[8], t[9] = sec, mnt, hr, dow, date, mon, yr
    return t, alarm_match(t), dst_done, ev


def alarm_match(t):
    """Alarm compare (p.3-711, p.3-713): each of the three alarm bytes
    matches its time byte or holds a don't-care code 11xxxxxx."""
    ok = True
    for alarm, now in ((t[1], t[0] & 0x7F), (t[3], t[2]), (t[5], t[4])):
        if not (alarm == now or (alarm & 0xC0) == 0xC0):
            ok = False
    return ok


def days_in_month(mon, yr, binary):
    """End-of-month recognition and leap years (feature list, p.3-699).
    ASSUMPTION R8: a year is a leap year when its two-digit value is
    divisible by 4 (00 included). ASSUMPTION R9: an out-of-range month
    has 31 days. Returned in the current data mode."""
    if binary:
        y4 = yr & 3
        feb, thirty = mon == 2, mon in (4, 6, 9, 11)
    else:
        # tens digit contributes 10*t = 2*t (mod 4); units digit u (mod 4)
        y4 = ((yr >> 4) & 1) * 2 + (yr & 3)
        feb, thirty = mon == 0x02, mon in (0x04, 0x06, 0x09, 0x11)
    leap = (y4 & 3) == 0
    if feb:
        d = 29 if leap else 28
    elif thirty:
        d = 30
    else:
        d = 31
    return d if binary else ((d // 10) << 4) | (d % 10)


# -------------------------------------------------------------------- scripts
def load_image(path):
    img = [0] * 64
    if not path:
        return img
    n = 0
    for line in open(path):
        line = line.split('//')[0].strip()
        for tok in line.split():
            if tok.startswith('@'):
                n = int(tok[1:], 16)
                continue
            img[n] = int(tok, 16)
            n += 1
    return img


class Runner:
    """Executes a test script on the model and writes the trace."""

    def __init__(self, model, out):
        self.m = model
        self.out = out
        self.last = None
        self.errors = []
        self.lineno = 0

    def emit_state(self, kind):
        st = (self.m.irq_n(), self.m.sqw())
        if kind == 'C':
            if st != self.last:
                self.out.write('C %d %d %d\n' % (self.m.ticks, st[0], st[1]))
        else:
            self.out.write('S %d %d %d\n' % (self.m.ticks, st[0], st[1]))
        self.last = st

    def fail(self, msg):
        self.errors.append('line %d: %s' % (self.lineno, msg))

    def expect_read(self, got, exp_tok):
        if exp_tok is None:
            return
        exp = int(exp_tok, 16)
        if got is None or got != exp:
            self.fail('read %s, expected %02X' %
                      ('Z' if got is None else '%02X' % got, exp))

    def rec_read(self, a, v):
        self.out.write('R %02X %s\n' % (a, 'Z' if v is None else '%02X' % v))

    def run(self, lines):
        m = self.m
        for raw in lines:
            self.lineno += 1
            line = raw.split('#')[0].strip()
            if not line:
                continue
            f = line.split()
            op, args = f[0].upper(), f[1:]
            if op == 'W':
                m.addr_strobe(int(args[0], 16))
                m.write(int(args[1], 16))
            elif op == 'WN':                     # whole cycle with CE high
                m.addr_strobe(int(args[0], 16), ce=False)
                m.write(int(args[1], 16), ce=False)
            elif op == 'R':
                a = int(args[0], 16)
                m.addr_strobe(a)
                v = m.read()
                self.rec_read(a, v)
                self.expect_read(v, args[1] if len(args) > 1 else None)
            elif op == 'RN':
                a = int(args[0], 16)
                m.addr_strobe(a, ce=False)
                v = m.read(ce=False)
                self.rec_read(a, v)
                if v is not None:
                    self.fail('bus driven with CE high')
            elif op in ('A', 'O70'):
                v = int(args[0], 16)
                # Board adapter (O70): port 70h bit 7 is the NMI mask and bit 6
                # is unused, so only bits 5-0 reach AD5-AD0.
                m.addr_strobe(v & 0x3F if op == 'O70' else v)
            elif op in ('RD', 'I71'):
                v = m.read()
                self.rec_read(m.addr, v)
                self.expect_read(v, args[0] if args else None)
            elif op in ('WD', 'O71'):
                m.write(int(args[0], 16))
            elif op == 'POLL':
                # POLL addr mask value maxreads ticks_between: read until
                # (v & mask) == value; ticks between reads.
                a, mask, val, mx, tb = (int(args[0], 16), int(args[1], 16),
                                        int(args[2], 16), int(args[3]), int(args[4]))
                ok = False
                for _ in range(mx):
                    m.addr_strobe(a)
                    v = m.read()
                    self.rec_read(a, v)
                    if v is not None and (v & mask) == val:
                        ok = True
                        break
                    for _ in range(tb):
                        m.tick()
                        self.emit_state('C')
                if not ok and len(args) < 6:     # 6th arg 'soft': no check
                    self.fail('POLL %02X never matched' % a)
            elif op == 'T':
                for _ in range(int(args[0])):
                    m.tick()
                    self.emit_state('C')
            elif op == 'RST':
                m.set_reset(int(args[0]))
            elif op == 'PS':
                m.set_ps(int(args[0]))
            elif op == 'Q':                      # expect IRQ pin [and SQW]
                if m.irq_n() != int(args[0]):
                    self.fail('irq_n %d, expected %s' % (m.irq_n(), args[0]))
                if len(args) > 1 and m.sqw() != int(args[1]):
                    self.fail('sqw %d, expected %s' % (m.sqw(), args[1]))
            elif op == 'M':                      # expect a location (no side effect)
                a, e = int(args[0], 16), int(args[1], 16)
                if m.view(a) != e:
                    self.fail('loc %02X = %02X, expected %02X' % (a, m.view(a), e))
            elif op == 'DUMP':
                self.out.write('M ' + ' '.join('%02X' % m.view(a) for a in range(64)) + '\n')
            else:
                raise SystemExit('unknown script op %r at line %d' % (op, self.lineno))
            self.emit_state('S')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('script')
    ap.add_argument('trace')
    ap.add_argument('--fast-shift', type=int, default=0)
    ap.add_argument('--nvram', default='')
    ap.add_argument('--coverage', default='')
    a = ap.parse_args()
    m = MC146818(load_image(a.nvram), a.fast_shift)
    with open(a.trace, 'w') as out:
        r = Runner(m, out)
        r.run(open(a.script).read().splitlines())
    if a.coverage:
        with open(a.coverage, 'w') as f:
            json.dump(m.cov, f, sort_keys=True)
    if r.errors:
        for e in r.errors[:20]:
            print('MODEL EXPECTATION FAILED:', e)
        sys.exit(1)


if __name__ == '__main__':
    main()
