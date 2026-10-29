# Formal Verification Plan: Intel 4002

## Overview

This document defines the formal verification strategy for the Intel 4002
reconstruction. Because the chip has no free-running internal sequencer
beyond the `sync`-resynchronized phase counter, a bounded environment with a
well-formed bus and otherwise unconstrained inputs proves the complete
protocol and storage behavior.

## Formal Verification Scope

### In Scope (Formal)
- Phase-counter sequencing and `sync` resynchronization.
- SRC address-register loading (nibble placement, bank-line gating).
- Chip selection (chip-number compare incl. the 4002-1/4002-2 variant bit
  and the P0 strap).
- Command decode: which OPA values write main memory, status characters,
  the output port, drive read data, or are ignored.
- Storage integrity: write-read consistency at an `anyconst` address and no
  cross-address corruption (main memory and status characters separately).
- Drive-enable gating: the chip never drives the bus unless selected, in
  X2/X3, under a read command; never during fetch/M phases, writes, or SRC.
- Output-port latch semantics (WMP updates, hold, reset clear).
- Reset behavior (all state cleared).

### Out of Scope (Simulation Only)
- Full-system integration with the 4004 CPU (covered by TB protocol
  equivalence and the 4004 build's own system regression).
- Electrical timing, refresh, and asynchronous reset behavior (spec
  Section 11).

## Environment (assumptions)

| ID | Assumption | Rationale |
|----|------------|-----------|
| A1 | `!rst_n` in the initial state | Standard reset entry |
| A2 | `sync` high exactly once every 8 clocks after reset release | Well-formed CPU instruction cycles; makes every phase deterministic so covers and equality checks are exact |

`data_i`, `cm_ram_i`, and `po_i` remain completely free in every cycle: the
prover chooses arbitrary bus traffic and address straps, so all properties
are proven for every possible instruction stream, not sampled ones. A later
`rst_n` deassertion is unconstrained and the golden model mirrors it, so
reset dominance is checked too.

## Property Categories

### Safety Properties (assert)

Properties that must always hold (guarded by `rst_n && !$initstate &&
$past(rst_n)`; immediate assertions inside clocked blocks — Yosys rejects
concurrent SVA):

| ID | Property | Priority |
|----|----------|----------|
| S1 | Full-state equality with the independent golden model: phase counter, OPR/OPA latches, address register, output port, every main-memory cell (via `anyconst` index), every status cell (via `anyconst` index) | P1 |
| S2 | Write-read consistency: a WRM to the `anyconst` main cell is observable as the driven nibble on a later RDM to the same cell; same for WRn/RDn on the `anyconst` status cell | P1 |
| S3 | No cross-address corruption: a committed write to one `anyconst` main address leaves a second, different `anyconst` main address unchanged; same pair for status | P1 |
| S4 | Drive-enable gating: `data_oe` implies (phase is X2 or X3) AND a 4002 read command AND `cm_ram_i` AND chip-number match; and the driven nibble equals the golden model's selected cell | P1 |
| S5 | Output-port semantics: `io_o` changes only at a selected WMP commit or reset; equals the golden model's port at every clock | P1 |
| S6 | Reset behavior: one cycle after `rst_n` falls, phase = 0, `data_oe` = 0, `io_o` = 0, address register = 0, and the `anyconst` cells read 0 | P1 |
| S7 | Address decode: after a SRC cycle with the bank line active, the address register equals the two driven nibbles per the manual's X2/X3 split | P1 |

### Liveness / Non-vacuity (cover)

>= 30 cover statements in `intel_4002_cover.sv`, all reachable within the
cover depth:

- Each of the 13 commands (WRM, WMP, WR0-WR3, SBM, RDM, ADM, RD0-RD3)
  executing with the chip selected.
- Write-read roundtrips returning matching nonzero data (main memory,
  status characters).
- WMP overwrite with a second, different value.
- SRC latch of extreme field values (register 0 and 3, character 0 and 15).
- Selection corners: own chip number selected; foreign chip number ignored;
  bank line low ignores SRC; command issued while unselected causes no
  drive.
- Read data observed on the bus at X2 and at X3.
- No drive during M1 of a RAM-command fetch.
- ADM/SBM supplying a nonzero memory nibble.
- Reset clearing a nonzero output port, and a write -> reset sequence
  reaching the post-reset cycle.
- Cycle wrap X3 -> A1.

37 covers total; every one is reached (zero unreached statements in the
cover PASS summary).

### Assumptions

See Environment table above; deliberately minimal (A1, A2 only).

## Proof Strategy

| Property Set | Engine | Mode | Depth |
|--------------|--------|------|-------|
| All safety properties | abc bmc3 | bmc | 30 |
| All safety properties | abc pdr | prove | unbounded |
| Cover set (37 statements) | smtbmc --unroll z3 | cover | 30 |

Depth 30 admits the worst-case property witness (reset + SRC cycle + write
cycle + read cycle = 25 clocks plus margin) and the deepest cover witnesses
(the SRC -> write -> read roundtrips, reached by step 19).

## Cover-Engine Decomposition (engineering record)

The cover task is the one mode SymbiYosys cannot run with the ABC engines
(`Invalid engine 'abc' for cover mode`), and z3 4.8.12 — the only SMT solver
in the tool image — does not converge on this design's natural encoding: the
main/status arrays become SMT arrays through `prep`, and with
`smtbmc --unroll z3` individual cover queries stalled for hours (the first
cover build never got past step 9; an incremental non-unrolled build and a
`--nomem` build were also far too slow to reach depth 30). Three changes,
in combination, brought the full cover run to PASS in about 90 seconds:

1. **`memory_map` + `opt -fast` on the cover task's Yosys script** (see the
   comment in `formal/intel_4002.sby`). The 64x4 and 16x4 arrays become
   plain flip-flops and mux logic, so z3 works on pure bitvectors instead of
   SMT array theory with sequential conditional stores and variable-index
   reads. The bmc/prove tasks keep their untouched script: the ABC engines
   map memories internally and already converge fast.
2. **The cover module no longer observes the array through the flattened
   views.** `c_reset_mem_clear` originally re-read the written cell through
   the 64-way `main_flat` mux, which pulled the whole array into the query
   cone of every cover. The fact it demonstrated (a written cell reads 0
   after reset) is *asserted* in `intel_4002_props` (`a_s6_main`, full-vector
   compare), so the cover now witnesses only the reachability of the
   write -> reset sequence; the cleared-cell observation stays with the
   assertion. `main_flat`/`stat_flat` remain module ports for interface
   parity and are folded away as unused.
3. **`--unroll` retained.** Empirically the unrolled encoding with mapped
   memories is the fastest of the tried combinations.

Abandoned approaches, kept for the record: plain `smtbmc z3` (incremental,
arrays) — stalled at step 9 after 23+ minutes; `smtbmc --nomem --unroll z3`
with the old cover module — ~4 minutes per step from step 0 (the flattened
view mux dominated); `abc bmc3` for cover — rejected by SymbiYosys; a
scripted-stimulus cover environment (the repository's 8259 approach) was
considered but became unnecessary once the array representation was fixed;
`smtbmc --stbv` showed no progress within its timeout and was dropped.

## File Organization

```
formal/
├── intel_4002.sby         — one file, [tasks] bmc/prove/cover
├── intel_4002_props.sv    — golden model + assert/assume (bmc, prove)
└── intel_4002_cover.sv    — cover enumeration (cover task, FORMAL_COVER)
```

The DUT instantiates the active property module under `` `ifdef FORMAL ``
(matching the repository's 4004 convention), so no bind statements are
needed.

## Success Criteria

- BMC passes at depth 30.
- PDR (unbounded) proof passes.
- All cover statements reachable within depth 30 (cover task PASSes — this
  is the non-vacuity witness for the whole property set).
- No timeouts, no unknown results; results recorded in
  `report/final_report.md`.

## Review Checklist

- [x] All specified properties captured (S1-S7)
- [x] Assumptions are justified and minimal (A1, A2)
- [x] No over-constraining (cover mode passes with free bus inputs)
- [x] Proofs are non-vacuous (36 reachable covers)
- [x] Results documented in the final report
