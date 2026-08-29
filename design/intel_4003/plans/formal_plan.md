# Formal Verification Plan: Intel 4003

## Overview

Prove the full behavioral contract of `src/intel_4003.sv` (spec sections
4-8) with SymbiYosys: shift semantics, enable gating, serial-out behavior,
reset behavior and control gating, plus a cover set that demonstrates every
documented behavior is reachable (non-vacuity).

## Environment

- One `.sby` file (`formal/intel_4003.sby`) with tasks `bmc`, `prove`,
  `cover`; always run sby from the `formal/` directory so `[files]` paths
  (`../src/...`) resolve.
- Engines: `abc bmc3` (bmc), `abc pdr` (prove), `smtbmc z3` (cover).
- Depth 28 for all tasks: reset (2 cycles) + ten 2-cycle CP pulses
  (20 cycles) + margin comfortably covers the deepest documented behavior
  (a fully loaded register).
- Properties live in `formal/intel_4003_props.sv` (asserts) and
  `formal/intel_4003_cover.sv` (covers), instantiated from the RTL under
  `` `ifdef FORMAL `` / `` `ifdef FORMAL_COVER `` exactly like the
  `intel_4004` core. All assertions and covers are immediate statements
  inside clocked `always @(posedge clk)` blocks (Yosys rejects concurrent
  SVA).
- Input assumptions: reset is asserted in the initial state
  (`assume (!rst_n)` at `$initstate`) so all state is defined; everything
  else (CP, DATA IN, ENABLE, later resets) stays free.

## Property Categories

### Safety (assert)

| ID | Property | Source |
|----|----------|--------|
| S1 | Shadow-model equivalence: DUT `sr`/`cp_prev` equal an independently coded reference pair driven by the same pins, from the first post-reset cycle onward | spec 6.6 |
| S2 | On a shift event, `sr[0]` equals the previous-cycle DATA IN and `sr[9:1]` equals the previous `sr[8:0]` (stage-by-stage propagation, `$past`-based) | spec 6.6 |
| S3 | Without a shift event, `sr` holds its value (proves "no shifting when not enabled" / one-shift-per-pulse gating: CP held high cannot retrigger) | spec 6.2, 6.6 |
| S4 | `cp_prev` equals the previous-cycle CP | spec 6.2 |
| S5 | `q_o == sr` when enabled; `q_o == 0` when disabled | spec 6.4 |
| S6 | `so_o == sr[9]`, independent of ENABLE | spec 6.4 |
| S7 | After any clock edge that sampled `rst_n` low, `sr` and `cp_prev` are zero (synchronous reset, including re-asserted resets; and they stay zero after release until the first CP pulse, via S3) | spec 8 |

Guards: every `$past`-referencing assertion is checked only under
`(rst_n && !$initstate && $past(rst_n))`; current-state assertions are
skipped during `$initstate`.

### Cover (non-vacuity)

33 covers enumerated in `formal/intel_4003_cover.sv`: per-stage single-bit
walk (10), all-zeros/all-ones/alternating fills, serial-out high and
high-while-disabled, enabled/disabled output states, shifting while
disabled, enable rise with non-zero register, pulse-width variants (1 and 3
cycles), CP held high with no extra shift, back-to-back pulses, DATA IN
change between pulses, ten-pulse fill counter, serial-out fall, reset mid-
pulse, and reset after a load. All are reachable within depth 28.

## Proof Strategy

| Task | Engine | Depth | Purpose |
|------|--------|-------|---------|
| bmc | abc bmc3 | 28 | Bounded check of all properties from a defined reset |
| prove | abc pdr | 28 | Unbounded proof (the design is a simple register pipeline; PDR should close) |
| cover | smtbmc z3 | 28 | Every cover reachable -> non-vacuity |

## Known Risks

- `$past` semantics inside immediate assertions: validated by construction
  (S1 equivalence is `$past`-free; S2/S3 are the standard pre/post-edge
  formulation) and cross-checked in simulation.
- COVER task must PASS (all covers reachable); if a cover is too deep it is
  reformulated, never left failing.
