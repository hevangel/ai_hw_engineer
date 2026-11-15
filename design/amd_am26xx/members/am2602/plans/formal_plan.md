# Am2602 formal plan

Reference: AMD 1974 Data Book pages 4-21..4-26; spec assumption ledger.

## Properties

1. **Complementarity** (all modes, per channel): `q == !q_n`.
2. **Clear dominance** (all modes, per channel): C̄D low forces the
   quiescent state.
3. **Reference-model equality** (bmc/cover, per channel): DUT equals a
   model written from the datasheet (trigger network !Ī0 ∨ I1, two-cycle
   edge history, PULSE_CYCLES down-counter, async clear).
4. **Pulse width** (bmc/cover, per channel): a completed run lasts
   exactly PULSE_CYCLES cycles.

## Scoping and limits

As in the family formal plan: mirror equality and width relate states
across hidden counters, so they are scoped to bmc/cover (depth 24,
exhaustive for the five-cycle observable history at PULSE_CYCLES = 4);
prove carries the induction-stable properties unbounded.

## Covers (non-vacuity)

Both Table I trigger paths per channel, retrigger during a run,
asynchronous clear terminating a run, held-clear inhibit, completed
full-width pulses on both channels, and channel independence (channel 1
running while channel 2 completes).
