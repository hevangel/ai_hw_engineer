# S/360 formal plan

## What is proved, and what is not

| Job | Claim | Method | Completeness |
|---|---|---|---|
| `ibm_s360_alu.sby` | The arithmetic unit implements the condition-code and overflow rules of A22-6821-7 pp. 27-30 and 53-55. | `bmc` and `cover`, depth 1, `smtbmc` + z3 | **Exhaustive**: the design is combinational, so one step covers all operand pairs and all eight selectors. |
| `ibm_s360_addr.sby` | The address adder computes `B + X + D` in 24 bits with zero-field suppression and wrap. | same | **Exhaustive** for the same reason. |
| `ibm_s360_psw.sby` | Field writes are isolated (address, ILC, CC, program mask, system mask); a whole-word load replaces every bit except the interruption code and ILC; the cycle that leaves reset clears all fields except the address. | `bmc` depth 8, `prove` depth 8 (induction), `cover` depth 12 | Proof by induction over the register state; unbounded in time. |
| `ibm_s360_cpu.sby` | The retirement contract (address advances by the fetched length or to the branch address, ILC matches, registers change only on retirement) **and** the program-check contract (a suppressed instruction does not retire, leaves CC unchanged, stores an old PSW with the updated address and the code in bits 16-31; interruption entry never coincides with retirement and clears the code/ILC fields; no fetch in the wait state). | `bmc` depth 12, `cover` depth 20, `smtbmc` yices | Bounded to 12 cycles — reset plus one complete instruction and its interruption sequence for the 2- and 4-byte formats. **Not** an instruction-level equivalence proof. |

## Why these formulations

- **Exhaustive where possible.** The arithmetic and address units are
  combinational, so a one-step BMC is a complete proof over their input space.
- **A second reading of the manual.** Reference expressions are written from
  the manual's prose (sign rules, carry semantics, algebraic comparison, the
  interruption sequence of pp. 71-72), not copied from the RTL. They catch
  implementation mistakes but not a shared misreading — that needs the external
  oracle of issue #383.
- **Retirement and suppression are separate contracts.** `LPSW` replaces the
  PSW instead of advancing the instruction address, so the sequential-advance
  clause excludes it and its completion is announced by `retire` in the load
  state.
- **Arbitrary instruction streams.** `mem_rdata` is free, so the core
  properties hold for any instruction bytes and any old/new PSW contents.
- **Reset assumption.** `$initstate` assumes `!rst_n`; without it,
  unconstrained initial registers make `$past` comparisons meaningless.

## Engines and depths, and the measured cost

| Job | bmc | prove | cover |
|---|---|---|---|
| ALU | depth 1, `smtbmc z3` | — | depth 1, `smtbmc z3` |
| Address | depth 1, `smtbmc z3` | — | depth 1, `smtbmc z3` |
| PSW | depth 8, `smtbmc z3` | depth 8, `smtbmc z3` induction | depth 12, `smtbmc z3` |
| Core | depth 12, `smtbmc yices` (≈ 177 s) | not claimed | depth 20, `smtbmc yices` (≈ 146 s) |

**Core induction is not claimed.** `mode prove` was attempted at depth 12:
the base case passed in about two minutes, but temporal induction did not
converge after nine minutes, and z3 was slower still. The task was removed from
the job rather than left as an unbounded check. Closing induction needs an
abstraction of the register file.

## Non-vacuity

Every job defines covers, and all covers must be reachable:

- ALU: overflow, subtraction overflow, signed comparison across overflow,
  unsigned comparison high/low, zero results for AND/XOR, negative `LAT`.
- Address: zero-everything, maximum address, 24-bit wrap, zero displacement.
- PSW: all field strobes at once, a nonzero whole-word load, program mask 0xF,
  problem and wait state, CC 3.
- Core: operation exception (1), specification (6), `LPSW`/`SSM`/`SPM`
  retirement, a load with a nonzero address, interruption pending, overflow
  flag, wait state, check-state reach.

Covers deliberately **not** claimed, with the reason:

| Cover | Why not claimed |
|---|---|
| Privileged operation (2) | needs a `LPSW` into problem state before the privileged instruction; the cover proof at depth 28 did not converge in a 10-minute budget. Exercised by simulation test 6; the suppression property that would carry code 2 is proven for the cases BMC reaches. |
| Fixed-point overflow (8) | needs an `SPM` (or masked `LPSW`) before the overflowing operation; same budget limit. Exercised by simulation test 7. |
| Two-instruction prefixes in general | the core job is a bounded proof; longer prefixes are simulation territory until an abstraction exists. |

## Defects the formal work found

1. `retire` was tied to the commit state, so `LPSW` — which completes through
   its own load states — never announced completion. The unreachable
   `retire && op == OP_LPSW` cover exposed it.
2. An earlier M1 cover set paired a retirement with the condition code the
   retiring instruction sets, sampling the previous code; and the overflow cover
   exposed `ovf_pending` latching on `LR`'s adder pass-through. Both are
   recorded in the M1 report.

## Limits recorded for the record

1. The core job is bounded at 12 cycles; it can reach one complete instruction
   and its interruption sequence, not longer program prefixes.
2. There is no formal memory model: loads and new-PSW reads return
   unconstrained data, which makes the properties universal over contents but
   means "load returns what was stored" is only checked in simulation.
3. Nothing here proves the encoding table against IBM's intent (#383).
4. No liveness, fairness or timing property is claimed.
