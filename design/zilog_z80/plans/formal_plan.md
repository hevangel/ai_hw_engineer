# Zilog Z80 formal verification plan

## Overview

Formal proof covers the parts of the Z80 where an exhaustive or unbounded
argument is cheaper than a corpus: the byte ALU's flag equations, decoder
totality over every opcode byte, and the transaction-contract invariants that a
simulation corpus can only sample. The instruction set itself is verified by the
independent oracle and the exercisers; proving all 256+ opcodes against a
hand-written reference would duplicate the oracle without adding independence.

## Scope

**In scope (formal)**

- ALU flag equations for `ADD`, `ADC`, `SUB`, `SBC`, `CP`, `AND`, `OR`, `XOR`,
  `INC`, `DEC`, `DAA`, `CPL`, `NEG`, rotates and shifts, including F3/F5
  sources, against equations derived from the external oracle and the flag table.
- Decoder totality: every byte of every page (primary, CB, ED, DD, FD,
  DD-CB, FD-CB) decodes to a defined instruction or documented ignore path.
- Transaction contract: no architectural advance without acknowledgement,
  stable request payload while stalled, exactly one write per write transfer.
- Architectural invariants: R increments once per M1 fetch with bit 7 preserved;
  PC contract after retirement; IFF1/IFF2 rules; HALT freezes PC; reset values.
- Reachable covers for every page, interrupt mode, block-instruction phase,
  HALT entry/exit and the refresh cycle.

**Out of scope (simulation only)**

- Full-ISA equivalence proofs; the oracle corpus covers them.
- Native M-cycle timing counts and pin waveforms; the timing comparison covers
  them, and a cycle-accurate formal model would restate the tables it checks.
- Analog and electrical behavior; never in scope for this design.

## Property categories

### Safety properties (`assert`)

| ID | Property | Module | Priority |
|---|---|---|---|
| S1 | No state advance while `bus_req_o` is unacknowledged | `zilog_z80` | P1 |
| S2 | Request address, direction, space and data stable while stalled | `zilog_z80` | P1 |
| S3 | At most one write per write transfer | `zilog_z80` | P1 |
| S4 | Every opcode byte of every page retires or follows a documented ignore path; never faults | `zilog_z80_decoder` | P1 |
| S5 | R increments exactly once per M1 fetch and bit 7 is preserved | `zilog_z80_regfile` | P1 |
| S6 | `retire_o` pulses exactly once per instruction | `zilog_z80` | P1 |
| S7 | PC after retirement equals the instruction's documented next address | `zilog_z80` | P2 |
| S8 | INT acceptance clears IFF1 and IFF2; `RETN` sets IFF1 = IFF2; `EI` defers one instruction | `zilog_z80_core` | P1 |
| S9 | PC does not change while halted | `zilog_z80_core` | P1 |
| S10 | After reset PC = I = R = 0, IM = 0, IFF1 = IFF2 = 0 | `zilog_z80` | P1 |

### ALU equivalence

| ID | Property | Method |
|---|---|---|
| A1 | Result and all eight flags equal the oracle-derived equations for every 16-bit operand pair | `smtbmc` with `anyconst` operands, per operation |
| A2 | F3/F5 equal the documented source (result, operand, WZ high byte) per operation class | `smtbmc`, per class |
| A3 | `DAA` matches the documented correction table for every A/N/H/C input | `smtbmc` exhaustive grid |

### Liveness and reachability (`cover`)

| ID | Property |
|---|---|
| C1 | Every primary-page opcode slot is executed at least once |
| C2 | Each prefix page (CB, ED, DD, FD, DD-CB, FD-CB) is entered |
| C3 | Each interrupt mode (0, 1, 2) is accepted |
| C4 | NMI entry and `RETN` restoration are reached |
| C5 | HALT is entered and exited by an interrupt |
| C6 | A refresh cycle is issued after an M1 fetch |
| C7 | Each block-instruction phase (first, middle, terminal) is reached |

### Assumptions (`assume`)

| ID | Assumption | Rationale |
|---|---|---|
| A1 | Reset asserted for the first three clocks | UM0080 reset requirement |
| A2 | `bus_ready_i` is not starved forever | Harness liveness, not a chip guarantee |
| A3 | Memory and I/O models return a value for every acknowledged read | Model contract |

## Proof strategy

| Property set | Engine | Mode | Depth |
|---|---|---|---|
| ALU equivalence | `smtbmc z3` | bmc | complete per operation |
| Decoder totality | `abc pdr` | prove | unbounded |
| Transaction contract | `smtbmc z3` + `abc pdr` | bmc 40 + prove | — |
| Architectural invariants | `smtbmc z3` | bmc | 30 |
| Reachability | `smtbmc z3` | cover | 60 |

## File organisation

```
formal/
├── zilog_z80_alu_props.sv   — ALU equations and F3/F5 sources
├── zilog_z80_alu.sby        — ALU bmc tasks
├── zilog_z80_props.sv       — decoder, contract, architectural properties
├── zilog_z80.sby            — [tasks] bmc/prove/cover for the core
```

`.sby` files carry `[tasks]` so one configuration runs bmc, prove and cover, and
all properties sit inside `` `ifdef FORMAL ``.

## Success criteria

- Every bmc task passes at its depth; the unbounded decoder proof terminates
  `PASS`; no `unknown` or timeout result is reported as a pass.
- Every cover point is reachable; unreachable covers are either removed with a
  reason or recorded as an open gate.
- ALU equations trace to the external oracle and the pinned flag table, never to
  a reading of our own RTL.

## Results so far

Run with `sby -f formal/zilog_z80.sby <task>` in the project tool image
(Yosys 0.69, SBY 15, smtbmc/z3):

| Task | Result | Notes |
|---|---|---|
| `bmc` (depth 40) | PASS | contract properties, 62 s |
| `cover` (depth 60) | PASS | all six cover points reached at steps 16-18 |
| `prove` | PASS | k-induction, with the HALT/fault state invariants |

Properties currently proven: no retire while faulted; fault is sticky across
non-reset edges; HALT freezes PC; a stalled transfer keeps address, direction,
data and space stable; reset clears PC, IFF1, fault and halt; plus the
structural invariants `halted -> state == S_HALTED` and
`fault -> state == S_FAULT` that make the history properties inductive.

Not yet formal: ALU equivalence against oracle-derived equations
(property set A1-A3 in this plan) and decoder totality over every opcode byte.
Those are the next formal milestones, once the ED and index pages exist so the
statement is not "every unimplemented byte faults".

## Review checklist

- [ ] Properties state contract behavior, not implementation detail
- [ ] Assumptions are minimal and justified by UM0080
- [ ] Covers prove the properties are non-vacuous
- [ ] Results and any depth limits recorded in the report
