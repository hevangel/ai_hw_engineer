# S/360 test plan

Scope: the shared engine in `src/` and the self-checking testbench in `tb/`.
Later increments extend this plan; a test that does not exist yet is listed as
planned, never as passing.

## Exit criteria (current increment, M4)

1. `scripts/run_lint.sh` clean under `verilator --lint-only -Wall` for both the
   RTL and the testbench.
2. `scripts/run_sim.sh` passes, and its checks actually fail when an
   instruction is mis-executed (negative controls, §6).
3. `scripts/run_formal.sh` passes every defined task; every cover is reachable.
4. `scripts/run_synth.sh` completes with no latches and no undriven signals.
5. Every implemented instruction retires at the exact address the listing
   says; every implemented interruption stores the documented old PSW and
   loads the documented new PSW.

Not part of this increment: historical software, IBM diagnostics, timing,
protection, DAT, channel I/O, model-specific behaviour.

## 1. Directed program test

The M1 96-byte program at `0x0100` still runs unchanged: it exercises the 23 M1
operations, both branch outcomes, all address components, byte and word storage
access, and fixed-point overflow.

Checked: the exact retirement address sequence for 22 instructions followed by
the self-loop; final registers 1, 2, 3, 4, 5, 6, 15; final CC, ILC and
instruction address; storage at `0x208`, `0x20C`, `0x210`; the overflow flag.
No padding and no "landing tolerance": an instruction that retires at the wrong
place fails the test.

## 2. Program-interruption tests (M2)

Each test sets up memory, resets, runs a bounded number of cycles and checks
the stored old PSW, the interruption code, the loaded PSW and a marker written
by the handler.

| Test | Program | Checked |
|---|---|---|
| Operation exception | unassigned opcode `0x00` at `0x100` | code 1; old PSW `0x0000_0001_4000_0102` at `0x28` (code, ILC 1, IA 0x102); new PSW from `0x68`; handler ran (R15 = 0x304) |
| SPM | `LA 2,0x10; SPM 0,2; loop` | CC 0 and program-mask bit 36 from register bits 3-2 and 7-4; no interruption |
| SSM | `MVI; SSM; loop` (supervisor) | system mask 0x40; no interruption |
| LPSW | `LPSW 0x70` with system mask 0x80, CC 2, program mask 0xF, IA 0x120 | full replacement; control transferred; marker in R4 |
| Privileged operation | `LPSW` to problem state, then `SSM` | code 2; old PSW keeps the problem-state bit and stores IA 0x10C |
| Fixed-point overflow | `LA 2,0x10; SPM; L 4,0x7FFFFFFF; A 4,1` | code 8; old PSW CC 3, ILC 2, program mask 1, IA 0x10E; R4 = 0x8000_0000 |
| Specification | `LPSW 0x72` (unaligned) | code 6; IA 0x104; PSW not loaded |

### 2.1 Fixed-point completion and supervisor call (M3)

| Test | Program | Checked |
|---|---|---|
| Halfword group | `LH 1,0x200; AH 1,0x202; STH 1,0x204; CH 1,0x206; LA 2,7; MH 2,0x208` | R1 = -1 + 2 = 1; R2 = 7 × -2 = 0xFFFF_FFF2; the stored halfword lands in the high half of the word; CH sets CC 1 |
| Multiply / divide | `LA 4,6; L 3,-7; MR 2,4; ST 2/3; LA 6,0; LA 7,42; LA 8,42; DR 6,8` | 64-bit product 6 × -7 = 0xFFFF_FFFF_FFFF_FFD6 split across the pair; quotient 1 and remainder 0 in the pair |
| Divide exception | `LA 4,1; LA 6,1; DR 4,1` (dividend 2^32) | code 9, dividend registers unchanged, old PSW IA 0x10A |
| Shifts | `LA 2,5; SLA 2,1; SRA 2,1; LA 3,4; SLA 3,31` | R2 back to 5; R3 = 0 with CC 3 and the overflow flag; no interruption with mask bit 36 clear |
| Supervisor call | `SVC 42` | supervisor old PSW at `0x20`: bits 24-31 = 42, bits 16-23 zero; new PSW from `0x60`; handler runs |
| Odd halfword address | `LH 1,0x201` | code 6, IA 0x104, ILC 2 |
| Odd pair register | `MR 3,1` | code 6, IA 0x102, ILC 1 |

Suppressed checks also assert that the handler at `0x300` runs, which proves
the new PSW was fetched from `0x68` and made current.

### 2.2 Character and SS-format group (M4)

| Test | Program | Checked |
|---|---|---|
| SS chain | `MVC 0x208(4),0x200; XC; NC; OC; MVN; MVZ` | the four-byte field follows `C1C2C3C4 → 8A8E8E8A → 80828280 → C1828280 → CB828280 → 4B828280` |
| Compare / character | `CLC`, `IC`, `STC`, three `TM` masks | CC 1 from `CLC`; `R1` low byte 0x4B; stored byte at `0x20C`; `TM` gives CC 0, 1 and 3 for zero, mixed and all-one selections |

## 3. Arithmetic unit and address checks

Directed values from A22-6821-7, including the cases a naive implementation
gets wrong:

| Check | Expected |
|---|---|
| `0x7FFFFFFF + 1` | `0x80000000`, CC 3, overflow |
| `0x80000000 + 0x80000000` | `0`, CC 3, overflow |
| `0xFFFFFFFF + 1` | `0`, CC 0, no overflow |
| `0x80000000 - 1` | `0x7FFFFFFF`, CC 3, overflow |
| `CMP 0x80000000, 1` | CC 1 — a 32-bit subtractor would report CC 2 here |
| `CLR 0xFFFFFFFF, 1` | CC 2 (binary comparison) |
| `LTR 0x80000000` | CC 1 |
| zero-base/zero-index, wraparound and high-byte-ignored addresses | as computed in §4 of the M1 report |

## 4. Decode checks

`0x82` → `LPSW`/SI, `0x80` → `SSM`/SI, `0x04` → `SPM`/RR, `0x00` → unimplemented
RR, plus the instruction-length table (2, 4, 6 bytes).

## 5. Negative controls

The checks have failed when they should:

- before the two-byte fetch loop was corrected, the retirement-trace check
  failed at index 11 and the run ended in the watchdog;
- the formal cover for `retire && op == OP_LPSW` was unreachable and exposed
  that `LPSW` never announced completion;
- several testbench defects (string concatenation, PSW bit positions) produced
  failures that were fixed in the testbench, not by weakening the checks.

A testbench that has never failed is not evidence.

## 6. Formal checks

See [formal_plan.md](formal_plan.md): exhaustive combinational proofs for the
arithmetic unit and the address adder, a PSW field-isolation proof by
induction, and a core BMC at 12 cycles plus reachability covers for the
retirement and interruption contracts.

## 7. Planned tests (not yet implemented)

| Test | Issue | Gate |
|---|---|---|
| Differential comparison with an independent S/360 emulator | #383 | before any "compatible" claim |
| IBM diagnostic and test decks | #441 | after more of the instruction set and I/O exist |
| Supervisor-call, external and I/O interruptions, priority ordering | #385, #386 | when those sources exist |
| Storage protection and addressing exceptions | #385 | when storage limits and keys exist |
| IPL and CCW sequences | #386 | after channels |
| BOS/360 IPL and a real job through the reader/printer | #429 | after Model 30 (#393) and peripherals |
| Cycle-accurate comparison with A22-6825 timing tables | #389 | only after storage timing exists |
| Real-software regression per model | #451 | before any model sign-off |

## 8. What this test plan cannot establish

- That the decode table matches the architecture (the tests check the entries
  this project wrote down; an external oracle is required).
- That assigned-but-unimplemented instructions behave like a real machine —
  they raise code 1 by design in this increment.
- Any timing, performance or microarchitecture property.
- That any historical program runs.
