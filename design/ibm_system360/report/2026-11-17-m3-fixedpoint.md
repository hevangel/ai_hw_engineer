# IBM System/360 — M3: fixed-point completion and supervisor call

Date: 2026-11-17
Scope: the shared S/360 engine, third increment (program issue
[#379](https://github.com/hevangel/ai_engineer/issues/379), instruction-set
issue [#384](https://github.com/hevangel/ai_engineer/issues/384)).
Author: coding agent working under `AGENTS.md`.

## 1. What this increment adds

| Group | Instructions | Source |
|---|---|---|
| Halfword | `LH` (0x48), `STH` (0x40), `AH` (0x4A), `SH` (0x4B), `CH` (0x49), `MH` (0x4C) | pp. 26-30, 32 |
| Multiply | `MR` (0x1C), `M` (0x5C) | p. 30 |
| Divide | `DR` (0x1D), `D` (0x5D) | p. 31 |
| Shifts | `SLA` (0x8B), `SRA` (0x8A), `SLDA` (0x8F), `SRDA` (0x8E) | pp. 32-34 |
| Supervisor call | `SVC` (0x0A) with the supervisor-call interruption | p. 74 |
| New program checks | specification for an odd halfword address or odd pair register, and the fixed-point divide exception (code 9) | pp. 31, 34 |

The core now implements **41 operations**. Status switching and program
interruptions from M2 are unchanged, except that the interruption sequence
takes the old/new PSW addresses from a registered pair so that the
supervisor-call class can use `0x20`/`0x60`.

## 2. Semantics taken from the manual

- `MR`/`M`: the multiplicand is the **odd** register of the `R1` pair, the
  multiplier is the second operand, the 64-bit product replaces the pair, and
  an odd `R1` is a specification exception (p. 30). No overflow is possible.
- `MH`: fullword × sign-extended halfword, low 32 bits kept, no overflow
  indication (p. 32).
- `DR`/`D`: the pair is the 64-bit dividend; quotient in the even register,
  remainder in the odd register; the dividend registers are unchanged when the
  quotient does not fit 32 bits or the divisor is zero (pp. 31, 34).
- Shift amounts come from the **low six bits of the second-operand address**,
  which is not used to address storage and is not checked for addressing
  exceptions (p. 34). `SLA`/`SLDA` keep the sign bit and report overflow when a
  bit unlike the sign leaves the integer field; the result is stored and CC is
  3 (pp. 33-34).
- `SVC`: instruction bits 8-15 go to old-PSW bits 24-31, bits 16-23 are zero,
  old/new PSWs are at `0x20`/`0x60`, and the instruction is valid in both
  states (p. 74).

## 3. Results

### 3.1 Lint

`verilator --lint-only -Wall` on the RTL and the testbench: **0 warnings, 0
errors**.

### 3.2 Simulation

`tb_ibm_s360_cpu` reports `IBM S360 M3 CORE TESTS PASSED (108 checks)`. The complete flow (`scripts/run_all.sh`: lint, simulation, structural synthesis and the four formal jobs) passes in 363 s of wall time on this machine.

| Test | Establishes |
|---|---|
| 1. M1 program | 22 instructions retire at the exact addresses; final registers, storage, CC, overflow |
| 2-8. M2 interrupts | operation (1), SPM, SSM, LPSW, privileged operation (2), overflow (8), unaligned LPSW (6) |
| 9. Halfword group | `LH`/`AH`/`STH`/`CH`/`MH`: R1 = -1 + 2 = 1, R2 = 7 × -2 = 0xFFFF_FFF2, halfword stored in the high half of the word, CC 1 from `CH` |
| 10. Multiply/divide | 64-bit product 6 × -7 split across the pair; `DR` quotient 1 and remainder 0 |
| 11. Divide exception | code 9, dividend registers unchanged, old PSW IA 0x10A |
| 12. Shifts | `SLA`/`SRA` round trip; `SLA 31` yields 0 with CC 3 and the overflow flag, without an interruption when mask bit 36 is clear |
| 13. Supervisor call | code 42 in old-PSW bits 24-31 at `0x20`, new PSW from `0x60`, handler runs |
| 14. Specification | odd halfword address (IA 0x104) and odd pair register (IA 0x102) both raise code 6 |
| 15. Directed units | arithmetic unit, address adder, decode table |

### 3.3 Formal

| Job | Task | Depth | Result | Measured |
|---|---|---|---|---|
| `ibm_s360_alu` | bmc / cover | 1 (exhaustive) | PASS | < 1 s |
| `ibm_s360_addr` | bmc / cover | 1 (exhaustive) | PASS | < 1 s |
| `ibm_s360_psw` | bmc / prove / cover | 8 / 8 / 12 | PASS | < 5 s |
| `ibm_s360_cpu` | bmc | 12 | PASS | ≈ 416 s with yices |
| `ibm_s360_cpu` | cover | 12 | not claimed — exceeds the budget (see below) | > 12 min |

The core job got 2.4× slower than M2 because the formal model now contains a
64-bit signed divider and two variable shifts; depth was reduced from 16 to 12
(one complete instruction plus its interruption sequence) to keep the flow
usable, and this is recorded rather than hidden.

The core **cover** task is defined in the `.sby` but is not run by the default
flow: the seven remaining covers (operation and specification exceptions,
`LPSW`/`LH`/`SLA` retirement, interruption pending, wait state) did not
complete within twelve minutes with either z3 or yices, because each cover
check has to reason about the divider at every step. Non-vacuity for the M3
instructions therefore rests on the directed simulation tests 9-14, which
execute each instruction and check its architectural result; this limitation is
stated rather than papered over.

### 3.4 Defects found by these checks

1. **The RR multiply used the storage operand as the multiplier.** `MR` read
   the second operand from `opnd_q` (the storage word) instead of the `R2`
   register; the simulation test showed 6 × -7 producing 49 (7 × 7), which
   pointed straight at the multiplexer. Fixed by selecting R2 for RR formats.
2. **The first version of the multiply test was itself wrong**: `MR 2,3` uses
   register 3 both as the odd half of the multiplicand pair and as the
   multiplier, so 7 × 7 = 49 was architecturally correct and the *expectation*
   was wrong. The test now uses `MR 2,4` and `DR 6,8`, and the report records
   that the manual's "multiplicand from the odd register" rule makes `R2 = R1+1`
   a trap for test authors.
3. **Formal property phase error.** The interruption properties compared a
   register read in an `always_ff` with `$past()` of a signal latched by the
   same edge, which is off by one cycle. The payload is now captured in
   registered copies (`raise_d`, `raise_len_d`, `raise_cc_d`) so every
   comparison reads the same cycle. The harness also got a reset-observation
   counter, because an unconstrained initial state made the checks fire before
   any reset (a spurious failure, not an RTL defect).

### 3.5 Synthesis

`yosys` with `hierarchy -check`, `synth -run begin:fine`, `check` and `stat`:
431 generic cells for the core (including instances), 57 for the arithmetic
unit, 5 for the address adder and 21 for the PSW register; 514 for the design
hierarchy. "Found and reported 0 problems" for every structural check and no
latches.

The flow stops **before ABC mapping**: full `synth` of the divider did not
complete within a ten-minute budget on this machine, so mapped area and timing
are not reported. The check still establishes that the RTL is synthesizable,
latch-free and structurally consistent.

## 4. Limits

Authoritative list: [../spec/spec.md](../spec/spec.md) §5. In summary:

- no decimal, floating-point, SS or character/logical instructions
  (`MVC`, `CLC`, `TR`, `TRT`, `ED`, `TM`, `IC`, `STC`, `EXECUTE`, …); they
  raise code 1;
- no protection, DAT or addressing exceptions;
- only program interruptions (SVC added); no external, I/O or machine-check;
- specification exceptions cover halfword/word/pair alignment and the `LPSW`
  doubleword rule, not odd instruction addresses or invalid register fields;
- divide-exception and `SVC` old-PSW addresses follow the suppressed-check rule
  by assumption A-6;
- no timing; formal core BMC is bounded at 12 cycles, induction is not claimed
  and the core cover task is out of the default flow for solver-cost reasons;
- **no independent oracle** (#383) — no compatibility claim.

## 5. Reproduction

```sh
docker run --rm -v "$PWD":/work -w /work ai-hw-engineer:latest \
    sh design/ibm_system360/scripts/run_all.sh
```

## 6. Next

1. Character/logical group and SS moves/compares plus `EXECUTE` (#384).
2. Decimal and floating point with their option profiles (#382, #384).
3. External, I/O and machine-check interruptions, priority ordering, storage
   protection and addressing exceptions (#385).
4. Independent oracle and diagnostics (#383, #441), then channels/IPL (#386),
   peripherals (#404-#408) and Model 30 (#393).
