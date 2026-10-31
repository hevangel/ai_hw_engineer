# MOS 8520 specification

## Scope and evidence

`mos_8520` has the 6526 interface (see `design/mos_6526/spec/spec.md`)
and reuses its timer, serial and interrupt blocks. The 8520 differences
follow MAME's `mos6526.cpp` at revision
`41a494b6ef80adc924ccb2bdba1ee69580276e0c`, which cites vAmigaTS hardware
test programs for its 8520 behavior. The qualified 6526 core and MAME's
6526 core disagree in classified ways (reload latency, /IRQ latency);
see the [plan](../plans/implementation_plan.md).

| Register | 8520 behavior |
|---|---|
| 8 | TOD bits 7..0; read releases the latch; write (to the clock) restarts it |
| 9 | TOD bits 15..8 |
| A | TOD bits 23..16; read latches all bits unless CRB bit 7 selects the alarm; write (to the clock) stops it |
| B | Reads $FF; writes ignored |
| E | CRA bit 7 does not exist (reads 0) |

TOD counting: a rising TOD-pin sample sets a pending flag; a phase-two/4
divider services it, incrementing the counter unless stopped. A carry out
of the low twelve bits ripples: the alarm comparator sees the intermediate
value with the low twelve bits cleared before the upper nibble increments.
The comparator is edge-triggered on time = alarm, including after writes;
the alarm interrupt source follows. Platform initialization: time and
alarm zero, clock stopped (a register-8 write starts it).

Timers: a high-byte write in one-shot mode force-loads the counter and
starts the timer. A high-byte write to a stopped timer, and the one-shot
start, reload the counter through the two-cycle load path (one cycle later
than the VICE-qualified 6526 profile). Interrupt sources reach the ICR one
cycle after they form; the interrupt block uses the 6526 "unaffected"
read profile.

## Assumption ledger

- ASSUMPTION: the 8520-specific timing (reload latency, delayed sources,
  TOD divider phase from platform initialization) follows the pinned MAME
  model and its cited vAmigaTS tests; it is not independently measured.
- ASSUMPTION: TOD-pin sampling once per phase-two cycle as in the 6526.
- Residual differences from MAME (six /IRQ-edge cycles and three ICR-read
  cases in 2,000,000 random cycles) are open; see the report.
