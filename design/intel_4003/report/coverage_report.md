# Coverage Report: Intel 4003

## Formal Cover Results (non-vacuity)

Task: `sby -f -d ../work/formal/cover intel_4003.sby cover` — engine
`smtbmc z3`, depth 28 — **PASS**, 33 of 33 covers reached, 0 unreached.

Every documented behavior of the part is individually reachable from the
defined reset state within the depth bound:

| Cover | Behavior demonstrated | Reached at step |
|-------|----------------------|-----------------|
| `c_reset_released` | Reset releases and the core runs | 2 |
| `c_stage_0`..`c_stage_9` | A single asserted bit can occupy each of the ten stages (10 covers) | 1-19 |
| `c_all_zeros` | Register re-reads all-zero after activity | ≤28 |
| `c_all_ones` | Full ten-pulse all-ones fill | ≤28 |
| `c_alt_01` / `c_alt_10` | Alternating fills in both phases | ≤28 |
| `c_two_low_ones` | Two consecutive new bits in stages 1:0 | 5 |
| `c_bookends` | First-sent bit at stage 9 while a new bit sits at stage 0 | ≤28 |
| `c_so_high` | Serial output asserted | ≤28 |
| `c_so_high_disabled` | Serial output asserted while outputs are masked | ≤28 |
| `c_outputs_on` | Enabled parallel outputs non-zero | ≤28 |
| `c_outputs_masked` | Disabled outputs read zero while the register is non-zero | ≤28 |
| `c_shift_disabled` | A CP pulse shifts while outputs are masked | ≤28 |
| `c_shift_enabled` | A CP pulse shifts with outputs enabled | ≤28 |
| `c_enable_rise` | Enable re-asserts over a non-zero register | 4 |
| `c_pulse_w1` / `c_pulse_w3` | One-shift-per-pulse for 1- and 3-cycle CP pulses | 2 / ≤28 |
| `c_cp_held_no_shift` | CP held high across cycles after a shift | 5 |
| `c_back_to_back` | Pulses separated by a single low cycle | 1 |
| `c_din_change` | DATA IN changes between pulses | ≤28 |
| `c_pulses_10` | Pulse counter reaches a complete 10-bit load | ≤28 |
| `c_so_fall` | Serial output falls as bits shift past stage 9 | ≤28 |
| `c_reset_mid_pulse` | Reset asserts while CP is high after activity | ≤28 |
| `c_reset_after_load` | Reset asserts after the register held non-zero data | ≤28 |

(Steps shown are from the printed summary; every cover additionally carries
its own witness trace under `work/formal/cover/engine_0/`.)

## Assertion Set (safety coverage)

| Group | Properties | Contract pinned |
|-------|------------|-----------------|
| Shadow-model equivalence | `a_equiv_sr`, `a_equiv_cph` | Full functional match with an independent reference, all cycles post-reset |
| Shift semantics | `a_shift_din`, `a_shift_chain` | Data-in to stage 0, stage-to-stage propagation on every pulse |
| Control gating | `a_hold`, `a_cp_hist` | No shift without a CP rising edge; exactly one shift per pulse; CP history bookkeeping |
| Output behavior | `a_q_on`, `a_q_off`, `a_so` | Enable gates Q0-Q9 only; serial out always tracks stage 9 |
| Reset | `a_reset_sr`, `a_reset_cph`, `a_reset_ref` | Synchronous clear on every reset-sampled edge, incl. re-assertion |
| Structural (RTL-inline) | `a_shift_gated`, `a_so_tracks`, `a_q_gated` | Combinational consistency of the pulse and output equations |

All properties are proven unbounded by the `prove` (abc pdr) task and
bounded-checked to depth 28 by `bmc` (abc bmc3).

## Simulation Coverage (behavioral)

The testbench's directed phase (D1-D9) plus the 600-operation LFSR random
phase exercise, with per-cycle scoreboarding against a 20-bit golden chain:
both bit orders, straight and mirrored loads with eight fixed words,
partial loads, CP pulse widths of one and eight clock periods, CP held high
across idle instruction cycles, simultaneous DATA IN + CP port writes,
cascade transit of a 20-bit word with an intermediate check at the
half-way point, reset mid-load and reload, enable masking and re-reveal,
and randomized CP/data/enable/RAM-port traffic. Final result:
`TEST PASSED: 31225 checks, 7807 cycles` with 0 failures.
