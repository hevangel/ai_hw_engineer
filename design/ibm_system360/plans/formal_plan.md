# S/360 M1 formal plan

## What is proved, and what is not

The formal work separates four claims, each with its own job:

| Job | Claim | Method | Completeness |
|---|---|---|---|
| `ibm_s360_alu.sby` | The arithmetic unit implements the condition-code and overflow rules of A22-6821-7 pp. 27-30, 53-55. | `bmc` and `cover`, depth 1, `smtbmc` + z3 | **Exhaustive**: the design is combinational, so one step covers all operand pairs and all eight selectors. |
| `ibm_s360_addr.sby` | The address adder computes `B + X + D` in 24 bits with zero-field suppression and wrap. | same | **Exhaustive** for the same reason. |
| `ibm_s360_psw.sby` | Field writes are isolated; a whole-word load replaces every bit; the cycle that leaves reset clears all fields except the address. | `bmc` depth 8, `prove` depth 8 (`smtbmc` induction), `cover` depth 12 | Proof by induction over the register state; unbounded in time. |
| `ibm_s360_cpu.sby` | The retirement contract: address advances by the fetched length or to the branch address, ILC matches the retired length, registers change only on retirement, comparisons and branches never write a register, stores have the documented byte enables, illegal opcodes halt before retiring. | `bmc` depth 12, `cover` depth 14 (`smtbmc` yices) | Bounded to 12 cycles — reset plus at least one complete instruction of any length — plus reachability covers. **Not** an instruction-level equivalence proof. |

## Why these formulations

- **Exhaustive where possible.** The arithmetic and address units are
  combinational, so a one-step BMC is a complete proof over their input space;
  no depth parameter can hide a case.
- **A second reading of the manual.** The reference expressions in the property
  modules are written from the manual's prose (sign rules, carry semantics,
  algebraic comparison), not by copying the RTL's expressions. They catch
  implementation mistakes but not a shared misreading — that requires the
  external oracle of issue #383, and this plan says so explicitly.
- **Retirement, not internal state.** The core properties are stated on the
  architectural interface (PSW, register file, storage strobes) plus the
  sequencer latches needed to express the contract.
- **Arbitrary instruction streams.** `mem_rdata` is left free, so the core
  properties hold for any instruction bytes the storage model could return,
  including unimplemented opcodes.
- **Reset assumption.** `$initstate` assumes `!rst_n`, so the model starts from
  a defined state. Without it, unconstrained initial registers make `$past`
  comparisons meaningless — during development this produced four spurious
  assertion failures, which is why the assumption and the "previous cycle was
  not a reset cycle" guard are both present.

## Engines and depths, and the measured cost

| Job | bmc | prove | cover |
|---|---|---|---|
| ALU | depth 1, `smtbmc z3` | — | depth 1, `smtbmc z3` |
| Address | depth 1, `smtbmc z3` | — | depth 1, `smtbmc z3` |
| PSW | depth 8, `smtbmc z3` | depth 8, `smtbmc z3` induction | depth 12, `smtbmc z3` |
| Core | depth 12, `smtbmc yices` | not claimed (see below) | depth 14, `smtbmc yices` |

Core-job measurements on the development machine: depth 6 ≈ 13 s, depth 10 ≈
51 s, depth 12 ≈ 2 min, cover at depth 14 ≈ 45 s. z3 was roughly an order of
magnitude slower than yices on this design; depth 24 did not complete within a
15-minute budget.

**Induction on the core is not claimed.** `mode prove` (k-induction with
`smtbmc`) was attempted at depth 12: the base case passed in about two minutes,
but temporal induction did not converge — it was still attempting induction
steps after nine minutes with no conclusion, and a second attempt with z3 was
slower still. The task was therefore removed from the job rather than left in
the flow as a failing or unbounded check. The bounded BMC plus the exhaustive
module proofs are the evidence for this milestone; closing induction needs an
abstraction of the register file, which belongs with a later milestone.

## Non-vacuity

Every job defines covers, and all covers must be reachable:

- ALU: overflow, subtraction overflow, signed comparison across overflow,
  unsigned comparison high/low, zero results for AND/XOR, negative result for
  `LOAD AND TEST`.
- Address: zero-everything, maximum address, 24-bit wrap, zero-field
  displacement.
- PSW: simultaneous field writes, whole-word load with nonzero data, CC 3.
- Core: retirement of `L`, `LA`, `AR`, `CR` and `LR`; a `ST` word write with
  all four byte enables; an `MVI` byte write with exactly one byte enable;
  `CLI` and `LTR` retiring with CC 0; `CLR` retiring with CC 0; `BC` taken and
  not taken; `BCR` taken; a halt with the program-check flag.

Covers that a single instruction cannot reach from reset — an overflowing
`ADD`, a negative `LOAD AND TEST`, a "first operand high" `COMPARE LOGICAL` —
are **not** asserted here. They require a two-instruction prefix; the ALU
covers prove those rules exhaustively and the directed simulation program
exercises the overflow path.

Unreachable covers were treated as defects in the test, and two real problems
were found this way:

1. Three covers paired a retirement with the condition code the retiring
   instruction sets. The PSW is written at the end of the retiring cycle, so
   those covers sampled the *previous* code; they were rewritten to sample one
   cycle later through captured `retire_d`/`retire_op_d` registers.
2. The overflow cover exposed an RTL defect: `ovf_pending` was latched from the
   adder's overflow output on every instruction, and `LR` drives the adder as a
   pass-through, so a `LR` between two operands of equal sign could raise a
   spurious fixed-point overflow. The latch is now qualified with the
   instruction's "sets condition code" property, and the simulation program's
   overflow check still passes.

## Limits recorded for the record

1. The core job is bounded at 12 cycles; it can reach a store, a taken branch
   and a halt, but not longer program prefixes.
2. There is no formal memory model: loads return unconstrained data, which is
   what makes the properties universal over instruction streams but means
   "load returns what was stored" is only checked in simulation.
3. Nothing here proves the encoding table against IBM's intent — that is the
   oracle job (#383).
4. No liveness, fairness or timing property is claimed.
