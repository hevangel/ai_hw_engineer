# IBM System/360 — M6: addressing exceptions and the external interruption

Date: 2026-11-23
Scope: the shared S/360 engine, sixth increment (program issue
[#379](https://github.com/hevangel/ai_engineer/issues/379), PSW/interruption
issue [#385](https://github.com/hevangel/ai_engineer/issues/385)).
Author: coding agent working under `AGENTS.md`.

## 1. What this increment adds

| Item | Behaviour | Source |
|---|---|---|
| Installed storage | new parameter `MEM_SIZE_BYTES`, default 64 KiB | p. 34 |
| Addressing exception | an operand, SS field or `TR` table reference at or beyond installed storage raises program check **code 5**; the instruction is suppressed and the old PSW carries the updated address | pp. 34, 72 |
| External (timer) interruption | a latched request is taken between instructions when system-mask bit 7 is set; old/new PSWs at `0x18`/`0x58`; interruption code `0x0080` (timer, bit 24) | pp. 16-17, Figure 17 |
| Wait state | an external interruption ends it, as the manual requires | p. 17 |

This is the first half of the "protection and interruptions" step: **storage
protection keys (code 4), instruction-fetch addressing exceptions, and I/O and
machine-check interruptions are still missing**, and are stated as such in the
specification.

## 2. Design decisions

- **Whole-field check for SS operations.** The core tests the first and last byte
  of both fields (and the top of the `TR` table) before storing anything, so a
  violating SS instruction is *suppressed*. The manual lets such an operation be
  *terminated part way*, with unpredictable results in the already-processed
  bytes (p. 34). Suppression is deterministic and testable; it is recorded as
  deviation A-8 rather than presented as architecture.
- **The timer request is latched, not edge-detected.** A request asserted while
  the mask is clear stays pending and is taken as soon as the program sets the
  mask, which is what the manual describes for masked interruptions (p. 15).
  A request held high continuously re-triggers after each entry.
- **External entry bypasses the usual `S_CHECK` two-step**: `S_CHECK` builds the
  old PSW from the current PSW with the IA unchanged (no instruction was
  executed) and enters the store/fetch sequence directly.

## 3. Results

### 3.1 Lint

`verilator --lint-only -Wall` on the RTL and the testbench: **0 warnings, 0
errors**.

### 3.2 Simulation

`tb_ibm_s360_cpu` reports `IBM S360 M6 CORE TESTS PASSED (149 checks)`.

| Test | Establishes |
|---|---|
| 19. Addressing exception | `L 1,0x200` loads `0x00010000`, `L 2,0x10(1)` addresses `0x10010` → code 5, old PSW `0x0000_0005` / `0x8000_0108` (ILC 2, IA 0x108), the target register unchanged, handler runs |
| 20. External timer | with system-mask bit 7 clear a pulse is *not* taken; after `SSM` sets bit 7 the pending request is taken → code `0x0080`, old PSW `0x0100_0080` / `0x4000_010C`, handler runs |

### 3.3 Differential oracle

The independent-emulator suite still reports **37/37 cases agree** after these
changes (`tools/oracle/run_diff.py`, with `ext_timer_req` tied low in the oracle
testbench).

### 3.4 Formal

Core BMC at depth 12 **passes** in about 525 s with the new logic. The first run
failed at once on the old-PSW store property: it allowed only the program and
supervisor-call addresses, so the external store to `0x18` was rejected. The
property now admits all three old-PSW pairs (`0x28`, `0x20`, `0x18` and their
second words) — the assertion was right to complain, the range was stale.

### 3.5 Defects found

Two test-side errors while writing the new tests, both caught immediately:

1. `LA 1,0xFFF0` is not encodable — `LA` carries a 12-bit displacement, so the
   test could not build an address past 64 KiB that way. Replaced with
   `L 1,0x200` from a data word holding `0x00010000`.
2. The `MVI` that arms the system mask used immediate `0x20` instead of `0x01`,
   so bit 7 stayed clear and the timer was (correctly) not taken. The test now
   sets `0x01`.
3. The formal old-PSW store property still listed only two old-PSW locations and
   rejected the external store at `0x18` (see §3.4).

## 4. Limits

- No storage protection keys or protection exceptions (code 4).
- No instruction-fetch addressing exceptions; only operand/field references are
  checked.
- No I/O or machine-check interruptions; the external class has only the timer
  source (no interrupt key or external signals).
- No timing; the timer is an input, not a modelled interval timer.
- Formal core coverage is unchanged, so the new addressing and external paths
  are not covered by the interruption property; they are covered by simulation.
- No independent-oracle coverage of the new paths yet (the oracle testbench ties
  the timer low and uses full 64 KiB storage).

## 5. Reproduction

```sh
docker run --rm -v "$PWD":/work -w /work ai-hw-engineer:latest \
    sh design/ibm_system360/scripts/run_all.sh
```

## 6. Next

1. Storage protection keys and protection exceptions (code 4).
2. Instruction-fetch addressing exceptions and the remaining specification
   checks (odd instruction address).
3. I/O interruptions with the channel subsystem (#386).
4. Oracle cases for the new exception paths, using an event-aligned driver.
