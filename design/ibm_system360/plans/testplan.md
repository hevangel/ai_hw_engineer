# S/360 M1 test plan

Scope: the shared M1 core in `src/` and its predecessor of record, the
self-checking testbench in `tb/`. Later milestones extend this plan; a test that
does not exist yet is listed as planned, never as passing.

## Exit criteria for M1

1. `scripts/run_lint.sh` clean under `verilator --lint-only -Wall` for both the
   RTL and the testbench.
2. `scripts/run_sim.sh` passes, and its trace check actually fails when a
   single instruction is mis-executed (negative control, §5).
3. `scripts/run_formal.sh` passes every defined task; every cover is reachable.
4. `scripts/run_synth.sh` completes with no latches and no undriven signals.
5. Every instruction in the implemented set is retired at the exact address the
   program listing says, and its architectural effect is checked.

Not part of M1 exit: historical software, IBM diagnostics, timing, protection,
interruptions, channel I/O, model-specific behaviour.

## 1. Directed program test (test 1)

A 96-byte hand-assembled program at `0x0100` exercises all 23 implemented
operations, both branch outcomes, all four RX addressing components (zero and
nonzero base, zero and nonzero index, displacement), byte and word storage
access, and fixed-point overflow.

Checked:

- the **exact retirement address sequence** for 22 instructions, then the
  self-loop address for every subsequent retirement (no padding and no
  "landing tolerance": an instruction that retires at the wrong place fails the
  test);
- final general registers 1, 2, 3, 4, 5, 6 and 15;
- final PSW condition code, ILC and instruction address;
- storage results at `0x208` (word store), `0x20C` (byte store) and `0x210`;
- `ovf_pending` set by the overflow case, `pc_check_pending` clear, not halted.

The program listing and the derivation of every expected value are in
`report/2026-11-05-m1-core.md` §3, so the expectations can be re-derived from
the manual without reading the RTL.

## 2. Illegal operation code (test 2)

Executing opcode `0x1C` (MULTIPLY, RR, not implemented) must stop the machine
in the cycle after decode: `halted` high, `pc_check_pending` high, the
instruction address unchanged at `0x0100`, and no retirement after the halt.
This protects the decode table from silently executing an unimplemented
operation as a no-op.

## 3. Arithmetic unit checks (test 3)

Directed checks against values computed from A22-6821-7, including the cases a
naive implementation gets wrong:

| Check | Expected |
|---|---|
| `0x7FFFFFFF + 1` | `0x80000000`, CC 3, overflow |
| `0x80000000 + 0x80000000` | `0`, CC 3, overflow |
| `0xFFFFFFFF + 1` | `0`, CC 0, no overflow |
| `0 - 1` | `0xFFFFFFFF`, CC 1 |
| `0x80000000 - 1` | `0x7FFFFFFF`, CC 3, overflow |
| `CMP 0x80000000, 1` | CC 1 (low) — **not** CC 2; a 32-bit subtractor would overflow here |
| `CMP 1, 0x80000000` | CC 2 (high) |
| `CLR 0xFFFFFFFF, 1` | CC 2 (binary comparison) |
| AND to zero / OR to ones / XOR to zero | CC 0 / 1 / 0 |
| `LTR 0`, `LTR 0x80000000`, `LTR 7` | CC 0 / 1 / 2 |

## 4. Address generation checks (test 4)

| Input | Expected |
|---|---|
| zero B and X fields, garbage registers, displacement `0x123` | `0x000123` |
| base `0xFFFFF000`, displacement `0xFFF` | `0xFFFFFF` |
| index 2 + displacement 1 | `0x000003` |
| base `0xFFFFFF` + index 2 + displacement 1 | `0x000002` (24-bit wrap) |
| base `0xAB123456` (high byte nonzero) | low 24 bits only, `0x123456` |

## 5. Negative control

The retirement-trace check was validated during development: before the fetch
loop was corrected, a two-byte RR instruction decoded with a stale second byte,
the trace check failed at index 11, and the test aborted on its watchdog. The
recorded run of that failure is what makes the passing run meaningful; a
testbench that has never failed is not evidence.

## 6. Formal checks

See [formal_plan.md](formal_plan.md). Summary: exhaustive combinational proofs
for the arithmetic unit and the address adder, a PSW field-isolation proof by
induction, and a 12-cycle BMC plus induction and covers for the core's
retirement contract.

## 7. Planned tests (not yet implemented)

| Test | Issue | Gate |
|---|---|---|
| Differential comparison with an independent S/360 emulator on every implemented instruction and random state | #383 | before any "compatible" claim |
| IBM diagnostic and test decks | #441 | after program interruptions (#385) |
| Overlap, unaligned and boundary operands, storage protection exceptions | #385 | after exceptions exist |
| IPL and CCW sequences | #386 | after channels |
| BOS/360 IPL and a real job through the reader/printer | #429 | after Model 30 (#393) and peripherals |
| Cycle-accurate comparison with A22-6825 timing tables | #389 | only after storage timing exists |
| Real-software regression per model | #451 | before any model sign-off |

## 8. What this test plan cannot establish

- That the decode table matches the architecture. It checks the entries this
  project wrote down, not IBM's intent; an external oracle (#383) is required.
- That unimplemented instructions behave correctly (they halt by design).
- Any timing, performance or microarchitecture property.
- That any historical program runs: no OS, compiler or diagnostic is executed.
