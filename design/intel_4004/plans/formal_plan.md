# Formal Verification Plan: intel_4004

## Overview

Prove that the RTL implements the spec's instruction semantics and bus
protocol for *all* opcode encodings and *all* architectural start states, not
just sampled cases. The core technique: an `anyconst`-driven golden
transition function in the properties module, compared against the DUT at
every instruction boundary.

## Formal Verification Scope

### In Scope (Formal)

1. **Architectural ISA equivalence** — for arbitrary start state and an
   arbitrary one-word instruction word, the committed state after the
   instruction cycle equals a spec-derived golden function. Covers every
   basic, RAM-group, and accumulator-group opcode and all 16 register /
   16 accumulator / 8 condition field values via unconstrained `anyconst`
   words.
2. **Two-cycle equivalence** — the same statement for the two-word
   instructions (JCN, FIM, JUN, JMS, ISZ) and FIN, with `anyconst` first and
   second words.
3. **Sequencer safety** — phase/cycle validity, `sync` exactly at phase A1,
   `cm_rom` exactly during A1-A3, `data_oe` only in specified windows,
   PC-increment-at-A1 (when not committed otherwise).
4. **Reset** — after reset release the architectural state matches spec
   6.4 (PC = 0, ACC = 0, CY = 0, SP = 0, CMD = 0); index registers are
   preserved.
5. **Non-vacuity (cover)** — every instruction class executes; both JCN
   outcomes; JMS to depth 3 plus the circular-overwrite case; BBL return;
   SRC then each RAM read/write class; DCL bank decode values; FIN and JIN;
   page-straddle branch (PC crossing a 256-word page boundary inside a
   two-word instruction).

### Out of Scope (Formal)

- Memory-side behavior (ROM/RAM models live in simulation only; in formal,
  bus reads are unconstrained inputs).
- Electrical timing, reset deassertion phase alignment (reset is assumed
  held until after the initial cycle), multi-cycle programs longer than the
  proof horizon (BMC depth).
- Full-program reachability: unbounded reachability of arbitrary programs is
  provided by the simulation regression instead.

## Method

- One `.sby` file, `intel_4004.sby`, with tasks `bmc` (ABC bmc3, 24
  frames), `prove` (ABC pdr), `cover` (smtbmc z3 with unrolled, scripted
  stimulus), following the working setup from the Intel 8259 design.
- Properties in `formal/intel_4004_props.sv` (assertions) and
  `formal/intel_4004_cover.sv` (cover harness). The props module binds
  against DUT internals via hierarchical references inside a
  `` `ifdef FORMAL `` block compiled with the design (same approach as
  prior designs).
- The golden model is written as pure combinational functions of the
  latched instruction word and pre-state, so the proof obligation per
  instruction is one combinational equivalence at the commit point —
  tractable for ABC on this 4-bit datapath.
- Reset is assumed only in the initial cycle; later `rst_n`, `test_i`, and
  all bus inputs remain free.
