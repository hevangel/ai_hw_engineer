# Am2600 formal plan

Reference: AMD 1974 Data Book pages 4-15..4-20; spec assumption ledger.

## Properties

1. **Complementarity** (all modes): `q_o == !q_n_o` in every reachable
   state.
2. **Clear dominance** (all modes): either clear low forces Q low and Q̄
   high; asynchronous, so it also holds off-edge by construction of the
   DUT registers.
3. **Reference-model equality** (bmc/cover): the DUT output equals a
   model written from the datasheet (trigger network, two-cycle edge
   history, PULSE_CYCLES down-counter, async clear).
4. **Pulse width** (bmc/cover): a completed run — no retrigger, no clear
   at either boundary — lasts exactly PULSE_CYCLES reference cycles.

## Scoping and limits

The mirror equality and the width property relate states across a hidden
count register that output equality does not constrain, so temporal
induction cannot close them; they are scoped to the bmc/cover tasks and
the prove task carries the induction-stable properties unbounded. With
PULSE_CYCLES = 4 the DUT's full observable history is five reference
cycles; the 24-step bmc explores every reachable (state, input history)
combination many times, which makes the bounded proof exhaustive for this
parameterization. This scope is recorded in the props header, the spec
and the final report.

## Covers (non-vacuity)

Each of the five documented trigger paths (Ī0↓, Ī1↓, I2↑, I3↑, I4↑ with
the other inputs holding), retrigger during a run, asynchronous clear
terminating a run for either clear pin, held-clear inhibit, and a
completed full-width pulse. The cover task must reach every one.
