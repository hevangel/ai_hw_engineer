# IBM System/360 — M8: storage protection keys

Date: 2026-11-25
Scope: the shared S/360 engine, eighth increment (program issue
[#379](https://github.com/hevangel/ai_engineer/issues/379), PSW/interruption
issue [#385](https://github.com/hevangel/ai_engineer/issues/385)).
Author: coding agent working under `AGENTS.md`.

## 1. What this increment adds

Storage protection as described on pp. 68-70:

| Item | Implementation |
|---|---|
| Block | 2 KiB, selected by `address[16:11]` |
| Block state | 4-bit key plus one fetch-protection bit |
| PSW key | bits 8-11 (`psw[55:52]`) |
| Reference permitted | block key = 0, or block key = PSW key |
| Fetch permitted | a permitted reference, or fetch-protection bit = 0 |
| Violation | program check **code 4**; suppress the instruction |
| Instruction classes checked | operand fetches (`L`, `A`, `S`, `C`, `CL`, `N`, `O`, `X`, the halfword group, `CLI`, `TM`, `SSM`, `LPSW`), stores (`ST`, `STH`, `MVI`) and SS fields (store side of operand 1, fetch side of operand 2) |

The key array powers up all-zero, which marks every block unprotected, so the
existing regressions are unaffected. `SET STORAGE KEY` and `INSERT STORAGE KEY`
do not exist yet, so the core exposes a **key load port** (`key_we`,
`key_block`, `key_data`, `key_fetch_protect`) as a test aid; it is labelled as
such in the specification, not presented as an instruction.

Deviation A-10 is recorded: a fetch violation *suppresses* the instruction
instead of terminating it with unpredictable results as pp. 34/69 allow.

## 2. Results

### 2.1 Lint

`verilator --lint-only -Wall` on the RTL and the testbench: **0 warnings, 0
errors**.

### 2.2 Simulation

`tb_ibm_s360_cpu` reports `IBM S360 M8 CORE TESTS PASSED (174 checks)`.

| Test | Establishes |
|---|---|
| 23. Store violation | block 0 carries key 1, PSW key 0 → `MVI` raises code 4, the old PSW holds `0x0000_0004`/`0x8000_0108`, storage at `0x200` is unchanged and the handler runs |
| 24. Fetch violation | block 0 carries key 1 with fetch protection, PSW key 0 → `L 2,0(1)` raises code 4, `R2` unchanged |
| 25. Matching key | block 0 key 1 with fetch protection, block 1 key 0; `LPSW` from block 1 installs PSW key 1 → the same `L 2,0(1)` now loads `0x1234_5678` with no interruption |

### 2.3 Formal

Core BMC at depth 12 **passes** in about 720 s. The key array is left free in
the formal model, so the properties hold for arbitrary keys, including protected
blocks.

### 2.4 Differential oracle

The suite still reports **37/37 cases agree**; with all keys zero the new checks
are inert, which is exactly what the run confirms.

### 2.5 Defects found while writing the tests

1. The first version of the `LPSW` operand set the key in PSW bits 4-7 instead
   of 8-11, so the "matching key" test failed with the key still zero. Fixed by
   placing the key at word-0 bits 23-20.
2. Two tests wrote `L 2,0(1)` as `58 20 00 00` (B2 = 0), so they addressed
   `0x000` instead of `0x200`. Test 24 passed for the wrong reason (any block-0
   fetch violated) and test 25 loaded zero. Both now use `58 20 10 00`.
3. A stale Verilator object directory produced a precompiled-header error after
   the port list changed; `work/sim/obj` has to be removed when ports change.

## 3. Limits

- `SET STORAGE KEY`/`INSERT STORAGE KEY` are missing; keys come from the test port.
- Instruction-fetch protection (the fetch-protection bit applied to instruction
  fetch) is not checked.
- I/O and machine-check interruptions are missing, and the external class still
  has only the timer source.
- Unaligned word operands and invalid register fields are still unchecked.
- No timing.

## 4. Reproduction

```sh
docker run --rm -v "$PWD":/work -w /work ai-hw-engineer:latest \
    sh design/ibm_system360/scripts/run_all.sh
```

## 5. Next

1. `SSK`/`ISK` so programs can manage keys, then instruction-fetch protection.
2. I/O interruptions with the channel subsystem (#386).
3. Oracle coverage for the exception paths, with an event-aligned driver.
