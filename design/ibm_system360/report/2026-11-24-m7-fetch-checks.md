# IBM System/360 — M7: instruction-fetch checks

Date: 2026-11-24
Scope: the shared S/360 engine, seventh increment (program issue
[#379](https://github.com/hevangel/ai_engineer/issues/379), PSW/interruption
issue [#385](https://github.com/hevangel/ai_engineer/issues/385)).
Author: coding agent working under `AGENTS.md`.

## 1. What this increment adds

Two checks that run before any instruction is fetched:

| Condition | Interruption | Old PSW |
|---|---|---|
| instruction address at or beyond `MEM_SIZE_BYTES` | program check **code 5** (addressing) | address unchanged, ILC 0 |
| instruction address odd | program check **code 6** (specification) | address unchanged, ILC 0 |

Both are taken between instructions in `S_CHECK`, after the external-timer and
pending-interruption checks and before the fetch, and both use the program old
and new PSWs at `0x28`/`0x68` (A22-6821-7 p. 72).

With this, every addressing check the specification lists for this core exists:
operand, SS field, `TR` table and instruction address. The remaining
specification gaps are unaligned word operands and invalid register fields.

## 2. Design notes

- **ILC 0 for an unfetchable instruction.** The manual says the stored
  instruction address has been updated by the number of halfwords in the ILC,
  but when nothing can be fetched there is no instruction length. The core
  stores the address unchanged with ILC 0; this is recorded as assumption A-9
  rather than presented as architecture.
- **The check is on the PSW address, not the halfword read.** An instruction is
  up to six bytes, so the last halfword of a long instruction could cross the
  top of storage. The core checks only the address the PSW holds, which matches
  the manual's wording ("an instruction halfword is located outside the
  available storage", p. 72) for the first halfword but does not model a
  boundary-crossing instruction.

## 3. Results

### 3.1 Lint

`verilator --lint-only -Wall` on the RTL and the testbench: **0 warnings, 0
errors**.

### 3.2 Simulation

`tb_ibm_s360_cpu` reports `IBM S360 M7 CORE TESTS PASSED (159 checks)`.

| Test | Establishes |
|---|---|
| 21. Odd instruction address | `LPSW` loads IA 0x105 → code 6, old PSW `0x0000_0006` / `0x0000_0105` (ILC 0), handler runs |
| 22. Instruction outside storage | `LPSW` loads IA 0x010000 → code 5, old PSW `0x0000_0005` / `0x0001_0000`, handler runs |

Both tests also prove the interruption happens *before* any fetch: no instruction
of the target address retires.

### 3.3 Formal

Core BMC at depth 12 **passes** in about 389 s with the new checks. The old-PSW
store property already admits the program pair, so the new paths needed no
property change.

### 3.4 Differential oracle

The suite is unaffected by the new checks (every case starts at an even,
in-range address) and still reports **37/37 cases agree**, which confirms the
added checks do not disturb normal fetching.

## 4. Limits

- No storage protection keys or code 4.
- No I/O or machine-check interruptions.
- Unaligned word operands and invalid register fields are still unchecked.
- Boundary-crossing instruction fetches are not modelled (§2).
- No timing.

## 5. Reproduction

```sh
docker run --rm -v "$PWD":/work -w /work ai-hw-engineer:latest \
    sh design/ibm_system360/scripts/run_all.sh
```

## 6. Next

1. Storage protection keys and protection exceptions (code 4).
2. I/O interruptions with the channel subsystem (#386).
3. Oracle coverage for the exception paths, with an event-aligned driver.
