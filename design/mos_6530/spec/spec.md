# MOS 6530 RRIOT specification

## Target and evidence

Implement the 1024-byte mask ROM, 64-byte SRAM, two eight-bit ports and
four-rate interval timer, including factory-configurable decode masks and
PB5/PB6 select ownership. Instantiate both KIM-1 masks, 6530-002/003, with
their real ROM bytes, and exercise manufacturer firmware on the existing
6502 functional core. No instruction-cycle fidelity is inferred from boot.

- [MOS 6530 datasheet](https://www.6502.org/documents/datasheets/mos/mos_6530_rriot.pdf).
- [KIM-1 User Manual, August 1976](https://bitsavers.org/components/mosTechnology/kim-1/6500-15B_KIM-1_Users_Manual_197608.pdf),
  section 3 memory map and Appendix H; [transcription](https://kim-1.com/usrman.htm).
- [Archived original ROMs and listing](https://www.zimmers.net/anonftp/pub/cbm/src/kim-1/index.html).
- Independent [MAME 6530 implementation](https://github.com/mamedev/mame/blob/master/src/devices/machine/mos6530.cpp).

## Native chip and mask interface

The chip receives phase-two `clk`, low reset `rst_n`, R/W, ten address
bits, ROM-select `rs`, resolved peripheral inputs and bus data. Transfers
commit on the falling edge; data drives only in high phase on selected
reads out of reset. DDRs and output latches reset to zero, timer IRQ disables,
and RAM is neither initialized nor erased by reset. Values/enables replace
physical inouts. Board logic supplies pin resolution/pull-ups.

Three `(MASK,MATCH)` parameter pairs select ROM, RAM and registers by
comparing `{PB5,PB6,RS,A9:A0}`. Mask 1 means significant; match 1 means
high. Matches must not overlap and MATCH must be zero outside MASK.
`SELECT_PINS` reserves PB5/PB6 from output drive when used for decode.
ROM contents are a constant packed parameter, byte zero in bits 7:0;
there are no RTL initial blocks, inferred runtime ROM writes or file loads.

KIM-1 uses PB6 as chip select and PB5 as data. The board adapter supplies
K5 active-low on PB6 and K6/K7 active-low on RS respectively for 003/002.
Within K5, A9:A8=11, A7 chooses RAM(1)/IO(0), A6 selects 002(1)/003(0).
This reproduces 002 ROM 1C00..1FFF, RAM 17C0..17FF, IO 1740..177F;
003 ROM 1800..1BFF, RAM 1780..17BF, IO 1700..173F. The adapter accepts
a 13-bit unexpanded KIM bus; upper-address aliasing belongs to board logic.

## Ports and timer

With register select A2=0, A1:A0 select PA,DDRA,PB,DDRB. A3 and other
non-decode bits mirror. Both ports read their output latch on driven bits
and resolved pins on input bits, per KIM manual Appendix H. The reserved
PB6 bit never drives even if DDRB6 is written. DDR readback preserves the
written byte in the current contract.

With A2=1, every write loads the timer; A1:A0 select /1,/8,/64,/1024.
A3 enables/disables timer interrupts. Even reads return the count; odd reads
return the flag in bit7 with bits6:0 zero. Flag reads never acknowledge.
N*P+1 clocks after a load the timer underflows to FF, latches its flag and
counts at /1. The first decrement occurs one clock after load. An even
read coincident with expiry preserves the new event. A later even read
acknowledges, restores the programmed divisor and disables IRQ regardless
of A3, per KIM Appendix H. Before expiry an even read sets enable from A3.
Reload clears the flag and reinitializes the interval.

PB7 is the physical timer IRQ pin. With DDRB7=0, a pending enabled timer
drives PB7 low. With DDRB7=1, the GPIO latch controls PB7 and suppresses
timer ownership. `irq_n` reports the chip's PB7 drive level; it is not an
independent 6532-style interrupt pin. A GPIO-low PB7 also reads as low on
that output. No PA7 edge detector exists in the 6530.

## Assumption ledger and sign-off boundaries

- ASSUMPTION: reset stops the timer and clears its count/flag; those internal
  reset values are not promised by MOS. Software must initialize the timer.
- ASSUMPTION: all effects are sampled on falling edges; subcycle electrical
  timing is not modeled. Validate native timing independently before sign-off.
- ASSUMPTION: DDR readback retains writes to mask-reserved PB5/PB6 bits but
  effective output enable suppresses them. Validate mask-reserved readback.
- ASSUMPTION: PA/PB output readback follows the KIM manual's latch semantics;
  externally loaded output voltages and physical contention are outside it.
- ASSUMPTION: acknowledged timer restarts with the returned count, with its
  first decrement on the next clock, supported by MAME `timer_r`; the KIM
  manual explicitly pins divider restoration and IRQ disabling, taking
  precedence over MAME's A3 enable behavior after underflow.
- KIM pin-mask equations are reconstructed from the manual memory map and
  decoder wiring. The test exhaustively checks the board map; a physical
  pin-level capture is still required for final mask/pin fidelity.
- The supplied ROMs remain original MOS firmware. The existing CPU is a
  functional bus core; any firmware integration result establishes software
  execution only and cannot prove real instruction-cycle timing.
