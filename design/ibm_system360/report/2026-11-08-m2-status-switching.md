# IBM System/360 — M2: status switching and program interruptions

Date: 2026-11-08 (verification runs on 2026-11-08 and 2026-11-09)
Scope: the shared S/360 engine, second increment (program issue
[#379](https://github.com/hevangel/ai_engineer/issues/379), PSW/interruption
issue [#385](https://github.com/hevangel/ai_engineer/issues/385)).
Author: coding agent working under `AGENTS.md`.

## 1. What this increment adds

M1 delivered fetch/decode/execute with 23 instructions and no interruption
mechanism. M2 adds the status-switching instructions and the program
interruption path defined on pp. 15-16 and 71-74 of A22-6821-7:

| Addition | Detail |
|---|---|
| `SPM` (0x04, RR) | register bits 2-3 → CC, bits 4-7 → program mask; not privileged |
| `SSM` (0x80, SI) | byte at the operand replaces PSW bits 0-7; privileged |
| `LPSW` (0x82, SI) | doubleword replaces the PSW; privileged; doubleword-aligned operand required |
| Program interruption | operation (1), privileged operation (2), specification (6), fixed-point overflow (8) |
| Old/new PSW | program old PSW stored at `0x28`, program new PSW fetched from `0x68` |
| Problem state | PSW bit 15 blocks privileged instructions with code 2 |
| Wait state | PSW bit 14 stops instruction fetching |

Suppressed program checks (1, 2, 6) leave the condition code, registers and
storage unchanged, and store an old PSW whose instruction address is advanced
by the instruction length — as p. 72 requires. Fixed-point overflow completes
the instruction (result and CC 3) and then interrupts when program-mask bit 36
is one (pp. 27-28).

## 2. Environment

```
image        ai-hw-engineer:latest
Verilator    5.052 2026-09-05 (rev v5.052)
Yosys        0.69 (git sha1 9f75ca1f9)
SymbiYosys   as packaged in the image; engines smtbmc z3 and smtbmc yices
```

## 3. Results

### 3.1 Lint

`verilator --lint-only -Wall` on the RTL and on the testbench: **0 warnings,
0 errors**.

### 3.2 Simulation

`tb_ibm_s360_cpu` reports `IBM S360 M2 CORE TESTS PASSED (66 checks)`. The
complete flow (`scripts/run_all.sh`: lint, simulation, synthesis and all four
formal jobs) passes in 427 s of wall time on this machine.

| Test | What it establishes |
|---|---|
| 1. M1 program | all M1 instructions, exact retirement-address trace (22 instructions), final registers, storage, CC, ILC, overflow flag |
| 2. Operation exception | unassigned opcode `0x00` stores old PSW `0x0000_0001_4000_0102` at `0x28` (code 1, ILC 1, IA 0x102), loads the new PSW from `0x68`, and the handler at `0x300` runs (R15 = 0x304) |
| 3. SPM | CC and program mask taken from register bits 3-2 and 7-4 |
| 4. SSM | system mask 0x40 written from storage in supervisor state |
| 5. LPSW | full PSW replacement: system mask 0x80, CC 2, program mask 0xF, control transferred to 0x120, register marker written |
| 6. Privileged operation | `SSM` in problem state stores code 2 with the problem-state bit preserved in the old PSW and IA 0x10C |
| 7. Fixed-point overflow | completed `A` retires, old PSW carries code 8, CC 3, program mask 1 and IA 0x10E; R4 = 0x8000_0000 |
| 8. Specification | unaligned `LPSW` stores code 6 with IA 0x104 and does not load the PSW |
| 9. Directed units | arithmetic unit, address adder and decode table checks |

### 3.3 Formal

| Job | Task | Depth | Result | Measured |
|---|---|---|---|---|
| `ibm_s360_alu` | bmc / cover | 1 (exhaustive) | PASS, 8/8 covers | < 1 s |
| `ibm_s360_addr` | bmc / cover | 1 (exhaustive) | PASS, 4/4 covers | < 1 s |
| `ibm_s360_psw` | bmc / prove / cover | 8 / 8 / 12 | PASS (field isolation by induction), 5/5 covers | < 5 s |
| `ibm_s360_cpu` | bmc | 12 | PASS | ≈ 177 s with yices |
| `ibm_s360_cpu` | cover | 20 | PASS, 10/10 covers | ≈ 146 s with yices |

Core covers: operation exception (1), specification (6), `LPSW`/`SSM`/`SPM`
retirement, a load with a nonzero instruction address, interruption pending,
overflow flag, wait state, and a check-state reach.

Codes 2 (privileged operation) and 8 (fixed-point overflow) are **not**
claimed as formal covers: each needs a two-instruction prefix (a `LPSW` to
enter problem state, or an `SPM` to enable the overflow mask) and the cover
proof at depth 28 did not converge within a 10-minute budget on this machine.
Both are exercised by simulation tests 6 and 7, and the suppression property
that carries code 2 is proven at the depth reached by BMC.

### 3.4 Defects found by these checks

1. **`LPSW` never retired.** `retire` was tied to the commit state, but `LPSW`
   completes through its own load states, so the instruction was invisible to
   the retirement contract and to any trace. Found by the formal cover for
   `retire && op == OP_LPSW`, which was unreachable. `retire` now also pulses
   in the load state, and the sequential-advance property excludes `LPSW`
   because it replaces the instruction address instead of advancing it.
2. **Testbench program strings were silently empty.** `"a" + "b"` is not
   string concatenation in SystemVerilog; those programs were written as
   garbage and the failures looked like RTL bugs. The literals are now single
   strings. (Test defect, not RTL.)
3. **Test expectations used the wrong PSW bit positions.** The condition code
   is in bits 34-35 (word 1 bits 29-28), not the top of the word, and the
   problem-state bit 15 is bit 16 of the first word. Both expectations were
   corrected against Figure 14. (Test defect.)

### 3.5 Synthesis

`yosys` with `synth -top ibm_s360_cpu`, `check` and `stat`: 4,692 cells for the
core (including instances), 885 for the arithmetic unit, 252 for the address
adder and 115 for the PSW register, 5,944 cells for the design hierarchy.
Yosys reported "Found and reported 0 problems" for every structural check and
inferred no latches.

## 4. Limits

Unchanged from M1 except where noted; the authority is
[../spec/spec.md](../spec/spec.md) §5:

- assigned-but-unimplemented instructions raise code 1, which is an
  implementation gap, not architecture;
- only program interruptions exist (no SVC, external, I/O, machine check);
- specification exceptions cover only the `LPSW` alignment rule;
- no protection, DAT, addressing exceptions or timing;
- wait state cannot be left because no I/O or external interruption exists;
- the core BMC is bounded at 12 cycles and induction is still not claimed;
- **no independent oracle**: the expectations are a reading of the same manual
  by the same author. Issue #383 is required before any compatibility claim.

## 5. Reproduction

```sh
docker run --rm -v "$PWD":/work -w /work ai-hw-engineer:latest \
    sh design/ibm_system360/scripts/run_all.sh
```

## 6. Next

1. `EXECUTE` and `SVC` plus the supervisor-call interruption (completes the
   status-switching chapter).
2. Remaining instruction groups: halfword, multiply/divide, shift, decimal, SS.
3. Independent oracle and corpus (#383), IBM diagnostics (#441).
4. Channels, IPL and peripherals (#386, #404-#408), then Model 30 (#393).
