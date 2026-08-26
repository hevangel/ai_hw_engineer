# Intel 8253/8254 Simulation Test Plan

## Goals

Verify the externally observable digital contract of both `IS_8254` elaborations: CPU programming, byte sequencing, all counters and modes, GATE behavior, count/status latching, binary/BCD behavior, reset, and invalid bus handling.

## Testbench architecture

`tb_top.sv` instantiates an 8253 and an 8254 on shared stimulus. Reusable tasks perform CPU reads/writes and sampled falling counter-clock pulses. Directed tests use specification-derived expected OUT timing and read values. Common-compatible operations are checked on both instances; variant-specific tests inspect each read bus independently.

The testbench records durable counters for CPU reads/writes, counter-clock pulses, mode/channel scenarios, aggregate latch/isolation/format/invalid-bus checks, read-back checks, BCD checks, interleaving checks, and failures. It prints stable markers consumed by `run_sim.sh`.

## Directed scenarios

| Area | Scenarios |
|---|---|
| Reset/bus | deterministic OUT state, no control-address drive, simultaneous read/write ignored |
| Addressing | all three counter addresses, selected counter isolation |
| Formats | LSB, MSB, LSB/MSB writes and reads |
| Modes | Modes 0–5 on every counter; aliases 6 and 7 |
| GATE | pause/resume, trigger/retrigger, Mode 2/3 force-high and restart |
| Mode 2 | periodic one-clock low pulse |
| Mode 3 | even and odd high/low durations |
| Modes 4/5 | one-clock strobe and retrigger behavior |
| Binary | terminal count and zero-as-65,536 programming image |
| BCD | decimal borrow and terminal behavior around `0002 → 0001 → 0000` |
| Count latch | stable snapshot, one-byte and two-byte consumption, no overwrite |
| 8254 read-back | per-counter selection, count only, status only, both, status priority, null count |
| 8253 read-back | command ignored with no state change |
| Variant phase | 8253 shared read/write phase versus 8254 independent phases |
| Coincidences | sampled GATE rise with counter-clock fall |

## Deterministic stress

A fixed-seed LFSR selects counters, legal modes, legal small counts, and trigger-versus-clock-pulse paths, then compares the two variants' common-mode OUT behavior. Stress is bounded to preserve deterministic runtime; reads, latches, invalid bus cycles, and idle timing are exercised by directed scenarios instead. Directed timing checks remain the primary mode oracle.

## Pass criteria

- Both elaborations compile and run in one simulation.
- Every mode/channel scenario is completed.
- All variant-specific latch/read-back/phase checks pass.
- No unknown externally visible value is accepted after reset.
- `Failures: 0` and `TEST PASSED` are printed.
- The simulation exits nonzero on any failed check.

## Coverage reporting

The flow reports functional scenario counts. No line, branch, or toggle percentage is claimed because the simulator does not produce a repository-standard code-coverage database.

## Completion results

Completed on 2026-08-26 in xezim 0.10.3. Both parameter values ran together for 21,462 cycles and 511 checks, covering all 18 mode/channel combinations, both alias encodings, five GATE checks, ten aggregate latch/isolation/format/invalid-bus checks, nine read-back checks, fifteen BCD checks, two phase checks, and 64 fixed-seed stress operations. The run performed 349 CPU writes, 51 CPU reads, and 10,260 sampled counter pulses with `Failures: 0` and `TEST PASSED`. Directed extensions include zero-count binary/BCD behavior, full 5,000/5,000-clock BCD Mode 3 phases, active retrigger timelines, counter isolation, complete read-back forms, and pre-arm trigger ordering. Every pass criterion above is satisfied.
