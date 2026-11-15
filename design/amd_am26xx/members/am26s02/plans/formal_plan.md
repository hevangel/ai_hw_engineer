# Am26S02 formal plan

Reference: 1974 preliminary sheet pages 4-33..4-38 and 1978 final data
pages 4-50..4-53; spec assumption ledger.

## Properties

1. **Complementarity** (all modes, per channel).
2. **Clear dominance** (all modes, per channel).
3. **Reference-model equality** (bmc/cover, per channel): trigger
   network !Ī0 ∨ I1, two-cycle edge history, PULSE_CYCLES down-counter,
   asynchronous clear.
4. **Pulse width** (bmc/cover, per channel): completed runs last exactly
   PULSE_CYCLES cycles.

## Scoping and limits

Family scoping applies: mirror equality and width are bounded
(bmc/cover depth 24, exhaustive for the five-cycle observable history);
prove is unbounded for the induction-stable properties.

## Covers (non-vacuity)

Both trigger paths per channel, retrigger, async-clear termination,
held-clear inhibit, completed pulses on both channels, channel
independence.
