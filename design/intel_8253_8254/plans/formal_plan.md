# Intel 8253/8254 Formal Verification Plan

## Scope

Prove compact, parameter-aware safety obligations for the shared timer engine and variant-dependent bus behavior, then demonstrate non-vacuous reachability through the real RTL. Formal uses the same `intel_8253_8254` implementation with dedicated 8253 and 8254 wrappers; no abstract replacement timer is used.

## Authored safety obligations

The checked-in external and inline assertions establish:

1. `data_oe` is asserted exactly for legal reads of counter addresses 0–2.
2. `data_o` is zero whenever the timer is not driving the CPU bus.
3. The cycle after reset has all three OUT signals high.
4. A legal mode-control write gives the selected counter the documented initial OUT value.
5. An 8254 status read returns the latched OUT bit and the programmed read/write format, raw mode, and BCD metadata. Null-count bit 6 is not part of this assertion.
6. Packed-BCD subtraction by one, two, or three preserves decimal nibbles for every valid packed-decimal input.
7. Known packed-BCD zero-wrap and borrow cases produce `9999`, `9998`, `9997`, `0008`, and `0000` as applicable.
8. A pending Mode 1 or Mode 5 trigger implies that a complete reload value is armed.
9. A Mode 4 terminal-low state recovers OUT high and stops on the next sampled counter-clock fall when no reload or engine write supersedes it, independently of GATE.
10. Mode 3 encoded-zero decrement produces `9998` in BCD or `fffe` in binary and preserves the current OUT phase.

Complete mode periods, full encoded-zero BCD Mode 3 phases, cross-counter isolation, latch and byte-phase timelines, complete read-back command forms, and active retrigger timelines are simulation obligations rather than formal proof claims.

## Assumptions

- Reset is asserted in the initial formal cycle; later reset is unconstrained in safety tasks.
- CPU strobes, addresses, data, GATE, and sampled counter-clock inputs are otherwise unconstrained for safety proofs.
- Properties over arbitrary packed-BCD values use an antecedent requiring all four nibbles to be decimal digits.
- Transition assertions exclude documented superseding events such as a simultaneous reload or selected-counter engine write.

## Reachability obligations

The cover monitor contains seven semantic points:

1. Program Mode 0 and observe its initial low OUT.
2. After that low state, observe Mode 0 OUT return high on the deterministic count-one trajectory.
3. Arm and trigger Mode 1, then observe OUT low.
4. Program Mode 2 and observe its low pulse.
5. Write a count and subsequently perform a driven read of the same counter.
6. Assert a noninitial reset and subsequently observe reset deassertion.
7. For 8254, issue read-back and subsequently perform a driven read; for 8253, exercise the read-back command encoding that the variant ignores.

The Mode 1 and Mode 2 predicates observe the stated output state; their causality comes from the deterministic legal wrapper sequences. The 8253 read-back point demonstrates command occurrence, while state preservation is checked in simulation.

## Configuration

- BMC: ABC `bmc3`, depth 16, for both parameter values.
- Prove: unbounded ABC `pdr`, for both parameter values.
- 8253 cover: four parameter-selected depth-10 synthesized/unrolled SMT tasks (`mode0`, `mode1`, `mode2`, and `bus_reset_readback`). Splitting avoids the stalled aggregate solve while retaining one real DUT in every task.
- 8254 cover: one depth-16 synthesized/unrolled SMT task containing all seven points.
- Cover engine: `smtbmc --syn --unroll --nopresat z3 rewriter.cache_all=true`.
- Inline `FORMAL_SAFETY` assertions are compiled into BMC/prove tasks, not cover tasks.

## Completion results

Completed on 2026-08-26 in container image `sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147`.

| Variant | Task | Bound/convergence | Semantic points | Latest witness | Result |
|---|---|---:|---:|---:|---|
| 8253 | BMC | depth 16 | Authored safety obligations | — | PASS |
| 8253 | Unbounded proof | PDR converged | Authored safety obligations | — | PASS |
| 8253 | `cover_8253_mode0` | depth 10 | 2/2 | step 7 | PASS |
| 8253 | `cover_8253_mode1` | depth 10 | 1/1 | step 6 | PASS |
| 8253 | `cover_8253_mode2` | depth 10 | 1/1 | step 8 | PASS |
| 8253 | `cover_8253_bus_reset_readback` | depth 10 | 3/3 | step 6 | PASS |
| 8254 | BMC | depth 16 | Authored safety obligations | — | PASS |
| 8254 | Unbounded proof | PDR converged | Authored safety obligations | — | PASS |
| 8254 | `cover_8254` | depth 16 | 7/7 | step 15 | PASS |

All seven cover points pass for each variant. The proof result is reported by semantic obligation rather than by generated backend output count.

## Success criteria

- [x] BMC and unbounded prove tasks pass for both variants.
- [x] Every authored safety obligation is represented accurately without equating backend output count to specification closure.
- [x] All seven real-DUT reachability points pass for each variant.
- [x] Simulation owns and passes the broader behavioral timelines not claimed by formal.
