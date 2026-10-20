# MOS 6526 CIA specification and fidelity ledger

## Evidence

- MOS [November 1981 preliminary datasheet](http://www.6502.org/documents/datasheets/mos/mos_6526_cia_preliminary_nov_1981.pdf):
  register map, resolved-pin reads, timer modes, serial buffering, ICR and TOD.
  This establishes existence by 1981, not an exact shipment date.
- [VICE timer implementation](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/core/ciatimer.h)
  and [CIA implementation](https://github.com/VICE-Team/svn-mirror/blob/d928b850b7ef4c1b1826a6efd175d8eaa80344d8/vice/src/core/ciacore.c),
  pinned revision `d928b850b7ef4c1b1826a6efd175d8eaa80344d8`:
  independent software oracle for timer pipelines, TOD quirks and interrupt
  sequencing. Compile unchanged external timer code with test-only service
  adapters; never modify expected values to match RTL.
- [Physical-chip measurements by merlintwa](https://www.forum64.de/index.php?thread/109935-mos6526-cia-detailed-test-vectors-and-models/),
  begun December 2020: separate PHI2 latches, timer/IRQ latency and serial
  input timing. These are reported measurements, not locally reproduced captures.
- [MAME CIA reference](https://github.com/mamedev/mame/blob/41a494b6ef80adc924ccb2bdba1ee69580276e0c/src/devices/machine/mos6526.cpp):
  another independent implementation, including positive TOD input edges.

## Device interface and registers

The complete chip uses PHI2 `clk`, reset, active-low chip select, R/W,
four-bit register address and eight-bit data bus; eight-bit ports with
separate output enables; CNT/SP input and open-drain output intents; FLAG,
TOD and PC handshake; active-low open-drain IRQ intent. Board-level
resolvers provide pullups and external contention, not hidden RTL defaults.

| Address | Register |
|---|---|
| 0/1 | PRA/PRB |
| 2/3 | DDRA/DDRB |
| 4/5 | Timer A low/high |
| 6/7 | Timer B low/high |
| 8/9/A/B | TOD tenths/seconds/minutes/hours |
| C | Buffered serial data |
| D | ICR: pending on read, set/clear interrupt enables on write |
| E/F | CRA/CRB |

Unlike a simple DDR-latch readback port, PRA/PRB reads reflect resolved
physical pin levels for output pins as well as inputs. Timer output can
override DDRB on PB6/PB7. PB access pulses PC low for one cycle; FLAG falling
edges set source 4 regardless of its mask. ICR sources 0–4 are timer A,
timer B, TOD alarm, serial and FLAG. Mask bit 7 selects set versus clear;
read clears pending and releases IRQ with revision-qualified pipeline timing.

## Timer subsystem contract

Sixteen-bit counter and latch per timer, pipeline-qualified start/stop,
force-load, one-shot and continuous operation. Timer A sources PHI2 or
positive CNT edges; timer B sources PHI2, CNT, timer-A underflow or A
underflow qualified by CNT high. Underflow reloads and may stop the timer.
PB output is a one-cycle positive pulse or toggle, set high when started.
Force-load bit reads zero. High-latch writes reload a stopped counter;
latch writes coincident with reload retain the externally established behavior.

The isolated `mos_6526_timer` uses a cycle-completion clock, decoded low/
high/control write strobes, continuous-count enable or external step pulse,
and read-only counter/latch/start/underflow outputs. Each cycle advances the
old timer state before applying the boundary's register write, matching the
external oracle API's documented update-before-write ordering. Underflow,
reload, start/stop and one-shot are checked every cycle, including zero
reloads and writes on underflow. No ideal N+1 timer replaces the pipelines.

## TOD and serial requirements

TOD divides positive 50/60 Hz edges into tenths, selected by CRA7. Registers
are BCD with AM/PM. Hours read latches all four values until tenths is read;
hours write stops counting and tenths write restarts it. CRB7 selects alarm
writes, while reads always return time. Hour rollover and the write-of-12
AM/PM quirk follow independent evidence rather than the preliminary manual's
ambiguous "24-hour (AM/PM)" wording. Alarm compares must include writes and
time changes, with transition/revision behavior separately verified.

Serial receive samples MSB first on qualified CNT events, transfers eight
bits to SDR and raises its source. Serial transmit uses timer-A underflow
to generate half-rate CNT, changes SP on falling CNT, buffers the next byte,
finishes after eight rising edges and returns CNT high. It must preserve
the last SP bit and handle buffered continuation and direction changes.

## Reset and unresolved assumptions

The preliminary sheet resets ports/control/pending/SDR/TOD to zero, timer
latches to FFFF and all port pins to inputs. VICE resets timer counters to
FFFF, stops TOD and uses hour 01 as a common physical value. TOD reset
and invalid-BCD behavior require an explicit revision/profile decision
before their RTL and final sign-off.

- ASSUMPTION: an isolated cycle-level timer models the pinned external
  emulator's pipeline profile; physical subcycle races require captures.
- Resolved port input latches and bus writes occupy distinct PHI2 phases.
  A once-per-clock pin model must not silently claim exact analog timing.
- Old-6526 IRQ delay and timer-B/read-ICR loss differ from later CIA models.
  Select and validate a revision before declaring full compatibility.
- Physical CNT-to-SP sampling can take multiple PHI2 edges; VICE explicitly
  approximates that path. Passing its emulator alone is insufficient there.

## Verification gates

First isolate and verify both timers against unchanged pinned external code
using deterministic and seeded-random per-cycle comparisons. Cover all
16-bit loads, zero/FFFF, stop/start, one-shot/continuous, force load, external
steps and reload/write races. Then integrate the port/ICR/TOD/serial paths
with their own meaningful regressions and reachable formal covers. Require
strict lint, formal BMC/prove/cover, simulation in two tools and synthesis,
plus external CIA software and physical timing evidence before system sign-off.
The timer foundation alone is not a completed CIA or C64 prerequisite.
