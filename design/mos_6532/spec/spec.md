# MOS 6532 RIOT specification

## Sources and scope

Primary: MOS/Commodore's [6532 datasheet](https://www.6502.org/documents/datasheets/mos/mos_6532_riot.pdf),
especially Internal Peripheral Registers, Interval Timer and Table 1.
Independent cross-check: [MAME mos6530.cpp](https://github.com/mamedev/mame/blob/master/src/devices/machine/mos6530.cpp),
`timer_start`, `timer_r`, `timer_end` and the 6532 address map. No emulator
source is copied into the implementation. This is a digital, clock-sampled
reconstruction, not a transistor or electrical timing model.

## Interface

`clk` is native phase two. Bus transfers and timer ticks commit on its
falling edge. Hold address, selects, R/W and write data through that edge.
Read data is combinational and driven only during high phase when selected,
reading and out of reset. `cs1=1, cs2_n=0` selects the chip; `rs=0` selects
RAM and `rs=1` selects registers. Seven address bits address 128 RAM bytes.
`rst_n` is sampled low on a falling edge; hold for a full clock period.

Inouts are split into data, output value and output-enable signals. `pa_i`
must contain **resolved PA pin levels including externally resolved output
drive**. PA reads the pins even on output bits. PB reads its latch on output
bits and `pb_i` on input bits. DDR bit 1 enables output; bit 0 is input.
The board supplies pull-ups/resolution; `irq_n=0` represents an asserted
open-drain IRQ (board integration must combine IRQ assertions).

## Register decode (RS=1)

A6:A5 are mirrors. With A2=0, A1:A0 select PA, DDRA, PB, DDRB;
A4:A3 are mirrors. With A2=1:

| Operation | Decode | Effect |
|---|---|---|
| Timer write | R/W=0, A4=1 | A1:A0 select /1,/8,/64,/1024; A3 enables timer IRQ |
| Edge control write | R/W=0, A4=0 | A0 selects rising (1)/falling (0); A1 enables PA7 IRQ; data ignored |
| Timer read | R/W=1, A0=0 | Return counter, acknowledge timer flag and set timer IRQ enable from A3 |
| Flag read | R/W=1, A0=1 | Return timer flag in D7, PA7 flag in D6, zero D5:0; acknowledge PA7 only |

Port writes latch all eight bits regardless of DDR. Reset zeros both latches
and DDRs, disables interrupts and selects falling PA7 edge. RAM survives
reset and has unspecified power-on contents.

## Timer and interrupts

A load of N with divisor P expires N*P+1 clocks after the write edge.
The first decrement is one clock after loading, subsequent decrements are
P clocks apart. Underflow from 0 to 255 sets the timer flag and enters /1
counting. The flag sets even when IRQ is disabled. A timer read coincident
with initial underflow cannot clear that new flag. A timer write reloads and
clears it. Flag reads leave it unchanged. PA7 transitions latch independently
of DDR and interrupt enable. Flag reads clear PA7; simultaneous new edges win.

## Assumption ledger and limitations

- ASSUMPTION: after underflow, an acknowledging timer read restarts the
  original prescaler using the returned count, with the first decrement one
  clock later. The datasheet is incomplete here; MAME's `timer_r` explicitly
  restores count mode. Subsequent /1 wraps before acknowledgment do not
  create fresh IRQ events (`timer_end`). Directed regression validates this
  contract; physical-chip comparison remains outstanding.
- ASSUMPTION: reset deterministically clears flags, stops the timer and
  initializes its internal count to zero. The manufacturer does not promise
  timer power-on contents. Software must load the timer before relying on it.
- ASSUMPTION: PA7 is sampled once per falling edge. Subcycle pulses,
  polarity-change glitches, metastability and edges during reset are outside
  this model. A sampled event wins over a simultaneous flag acknowledgment.
- No board/software sign-off yet. Atari software validation will be a
  separate integration gate; this peripheral is not a CPU.
