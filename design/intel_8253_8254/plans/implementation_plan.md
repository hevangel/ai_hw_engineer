# Intel 8253/8254 Implementation Plan

## Objective

Implement one synthesizable SystemVerilog module for both programmable interval timers. `IS_8254` is the only architectural variant parameter: it enables 8254 read-back/status and independent read/write byte phases; the 8253 setting ignores read-back and shares each counter's byte phase.

## Architecture

```text
CPU bus decode
  ├── control/latch/read-back decoder
  ├── byte read sequencer
  └── byte write sequencer
             │
             ├── Counter 0 state engine ── OUT0
             ├── Counter 1 state engine ── OUT1
             └── Counter 2 state engine ── OUT2
                    ▲
        sampled CLK falling/GATE rising events
```

A single `always_ff` process owns all state. Counter state is held in fixed-size unpacked arrays indexed 0 through 2. Combinational CPU read muxing is separate. Functions canonicalize mode aliases and perform packed-BCD decrement.

## State per counter

- programmed reload value and live counting element;
- read/write format, raw mode bits, and BCD flag;
- OUT, active-count, count-load pending, trigger pending, and Mode 3 first-tick state;
- null-count status;
- shared 8253 phase plus independent 8254 read/write phases;
- optional count and status latches.

## Implementation phases

- [x] Define the synchronous timing adaptation and same-cycle priorities.
- [x] Define the CPU address/control/read-back encodings.
- [x] Implement legal bus decode and read muxing.
- [x] Implement mode programming and byte sequencing.
- [x] Implement binary and BCD down-count behavior.
- [x] Implement Modes 0 through 5 and GATE semantics.
- [x] Implement 8254 read-back/status and 8253 rejection.
- [x] Add dedicated formal integration for both parameter values.
- [x] Pass lint, deterministic simulation, formal, synthesis, and coverage for both variants.

## Completion status

Implementation and validation completed on 2026-08-26. The single `intel_8253_8254` module elaborates both `IS_8254` values. Strict lint is clean; the dual-variant simulation passes 21,462 cycles and 511 checks with zero failures; both variants pass depth-16 BMC and unbounded PDR for the authored safety obligations; all seven real-DUT cover points pass for each variant; and both synthesize with zero structural problems.

## Design decisions

| Decision | Rationale |
|---|---|
| One module, `parameter bit IS_8254` | Directly satisfies shared-module requirement and prevents duplicated timer engines |
| One integration clock with sampled external clocks | Synthesizable and formally tractable while preserving independent event inputs |
| Fixed three counters and 16-bit width | These are architectural properties, not optional implementation knobs |
| Raw and canonical mode representation | Status returns the written bits while encodings 6/7 execute Modes 2/3 |
| Packed-BCD decrement function | Preserves four-decade behavior without non-synthesizable decimal conversion |
| Procedural self-checking testbench | Compact enough to cover both variants and all six modes without UVM overhead |
| Separate safety and reachability formal modules | Keeps proof logic focused and cover solving tractable |

## Constraints and exclusions

- Each sampled external level must remain stable long enough for edge detection.
- Integration provides synchronization for genuinely asynchronous inputs.
- Valid BCD writes contain four decimal nibbles.
- Modes 2 and 3 are programmed with counts of at least 2.
- Analog timing and original process/package behavior are excluded.

## Deliverables

- `src/intel_8253_8254.sv`
- `tb/tb_top.sv`
- `formal/intel_8253_8254_props.sv`
- `formal/intel_8253_8254_cover.sv`
- `formal/intel_8253_8254.sby`
- fail-fast lint, simulation, formal, synthesis, coverage, and aggregate scripts
- specification, README, coverage report, and final report
