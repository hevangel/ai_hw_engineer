# Intel 8253/8254 Coverage Report

**Validation date:** 2026-08-26  
**Container image:** `sha256:d2ffb0d844d69e4de521c2c8e376d46ea34f6edfec1d5069039895c1b2e6f147`

## Simulation coverage

The deterministic xezim regression instantiates both parameter values in one testbench. Directed scenarios check specification-derived timing and bus behavior; a bounded fixed-seed stress phase exercises legal programming and timer events. Stable counters in the simulation log provide the durable functional-coverage evidence.

```text
8253/8254 simulation result: 21462 cycles, 511 checks
CPU reads: 51, CPU writes: 349, counter pulses: 10260
Mode/channel scenarios: 18, aliases: 2, GATE: 5
Latch checks: 10, read-back checks: 9, BCD checks: 15, phase checks: 2
Stress operations: 64
Failures: 0
TEST PASSED
```

### Directed scenario closure

| Feature | Exercised | Result |
|---|---:|---|
| Both `IS_8254` elaborations | 8253 and 8254 in one run | PASS |
| Counter selection and isolation | Counters 0, 1, and 2 | PASS |
| Modes 0–5 | 6 modes × 3 counters = 18 scenarios | PASS |
| Mode aliases | Encodings 6 and 7 | PASS |
| Read/write formats | LSB, MSB, and LSB/MSB | PASS |
| Binary terminal behavior | Small counts and encoded zero | PASS |
| Packed-BCD behavior | Borrow, terminal behavior, and Mode 3 encoded-zero 5,000/5,000 phases | PASS, 15 checks |
| GATE behavior | Pause/resume, trigger/retrigger, pre-arm rejection, and restart classes | PASS, 5 checks |
| Aggregate latch/isolation/format/invalid-bus bucket | 3 isolation + 2 latch + 4 format + 1 invalid-bus checks | PASS, 10 checks |
| 8254 read-back | Count-only, status-only, combined, priority, selection, and null count | PASS |
| 8253 read-back rejection | Command leaves timer state unchanged | PASS |
| Variant byte phases | 8253 shared; 8254 independent | PASS, 2 checks |
| Invalid bus controls | No read drive or state mutation | PASS |
| Fixed-seed stress | 64 deterministic operations | PASS |

## Formal safety evidence

Dedicated wrappers elaborate `IS_8254=0` and `IS_8254=1` around the same shared RTL. The initial frame is reset-constrained; CPU controls, data, GATE, sampled counter clocks, and later reset are otherwise unconstrained.

| Variant | Task | Engine | Bound/convergence | Result |
|---|---|---|---:|---|
| 8253 | BMC | ABC `bmc3` | depth 16 | PASS |
| 8254 | BMC | ABC `bmc3` | depth 16 | PASS |
| 8253 | Unbounded proof | ABC `pdr` | converged | PASS |
| 8254 | Unbounded proof | ABC `pdr` | converged | PASS |

The proved obligations are bus-drive legality, zero undriven data, reset OUT state, post-programming OUT state, partial 8254 status metadata, packed-BCD digit validity and known zero/borrow results, Mode 1/5 pending-trigger arm validity, Mode 4 recovery when no reload/write supersedes it, and Mode 3 encoded-zero decrement with OUT preservation. Complete mode periods, isolation, latch/phase timelines, full read-back forms, and active retrigger timelines are simulation evidence, not formal proof claims.

## Formal reachability evidence

The cover monitor has seven semantic points: Mode 0 initial low and later high, triggered Mode 1 low, Mode 2 low pulse, count-write followed by a driven same-counter read, later reset recovery, and variant-specific read-back activity. Every task instantiates the real three-counter RTL.

| Variant | Task | Engine | Bound | Points | Witness steps | Elapsed | Result |
|---|---|---|---:|---:|---|---:|---|
| 8253 | `cover_8253_mode0` | synthesized/unrolled Z3 | 10 | 2/2 | 3, 7 | 478 s | PASS |
| 8253 | `cover_8253_mode1` | synthesized/unrolled Z3 | 10 | 1/1 | 6 | 394 s | PASS |
| 8253 | `cover_8253_mode2` | synthesized/unrolled Z3 | 10 | 1/1 | 8 | 545 s | PASS |
| 8253 | `cover_8253_bus_reset_readback` | synthesized/unrolled Z3 | 10 | 3/3 | 3, 4, 6 | 388 s | PASS |
| 8254 | `cover_8254` | synthesized/unrolled Z3 | 16 | 7/7 | 3, 7, 9, 11, 12, 13, 15 | 1,173 s | PASS |

The 8253 work is split into shallow parameter-selected scenarios because the prior aggregate task reached six points but did not complete within the execution timeout. The split preserves the predicates and real DUT while producing completed PASS artifacts. The 8253 read-back point establishes command occurrence; ignored-command state preservation is checked by simulation. The 8254 point establishes read-back followed by a driven read; detailed status/count forms are also simulation obligations.

## Coverage limitations

- No line, branch, toggle, or FSM percentage is claimed because the pinned xezim flow does not emit a repository-standard code-coverage database.
- Functional counts show scenario execution, not an exhaustive input-space percentage.
- The stress phase uses one fixed sequence for repeatability rather than statistical seed breadth.
- Formal proves only the authored obligations listed above, not every prose behavior in the specification.
- Sampled external-clock semantics require input levels to remain visible across integration-clock edges; metastability and clock-domain synchronization are outside the core.
- Electrical timing, drive levels, maximum historical clock grades, package behavior, and undocumented silicon behavior are outside scope.

Directed simulation, fixed-seed stress, BMC, unbounded proof, completed real-DUT cover tasks, lint, and synthesis structural checks collectively provide the verification evidence for this design.
