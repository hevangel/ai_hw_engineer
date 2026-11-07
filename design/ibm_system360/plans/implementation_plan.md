# S/360 family implementation plan

Scope: the shared engine and the per-model members of the IBM System/360
family. Program roadmap and acceptance:
[ai_engineer#379](https://github.com/hevangel/ai_engineer/issues/379).

## Milestones

| ID | Deliverable | Issue | Depends on |
|---|---|---|---|
| M0 | Source/provenance ledger and licensing policy | #381 | — |
| M0b | Architecture and model option matrix | #382 | M0 |
| M0c | Independent oracle and test corpus | #383 | M0 |
| **M1** | **Shared CPU engine: fetch/decode/execute, PSW, address generation, 23 instructions, formal + directed tests** | **#384** | **M0b (partial, this folder)** |
| M2 | PSW, interruptions, program mask, protection keys | #385 | M1 |
| M3 | Channel subsystem, CCW, IPL | #386 | M2 |
| M4 | Peripherals: 1052 console, 2501/2540 cards, 1403 printer, 2400 tape, 2311/2314 disk | #404-#408 | M3 |
| M5 | Model 30 as the first physical model | #393 | M2, M3, M4, #388 |
| M6 | Remaining models from their own documentation | #390-#403 | M5 pattern |
| M7 | Web control panel, simulated media, FPGA realization | #413, #412 | M5 |

## M1 (completed in this change)

Deliverables and their evidence:

1. `src/ibm_s360_defs.svh` — format classes, ILC, decode table, field extraction.
2. `src/ibm_s360_alu.sv` — 32-bit fixed-point and logical operations with the
   condition codes of A22-6821-7 pp. 27-30 and 53-55. Comparison uses a 33-bit
   difference so that signed comparison cannot be corrupted by overflow.
3. `src/ibm_s360_addr.sv` — 24-bit `B + X + D` with zero-field suppression and
   wrap.
4. `src/ibm_s360_psw.sv` — PSW register with isolated field writes and a
   whole-word load path for later `LPSW`/interruption work.
5. `src/ibm_s360_cpu.sv` — sequencer (idle, fetch, decode, execute, write,
   commit, halt) implementing 23 operations over a byte-addressed storage port.
6. `tb/tb_ibm_s360_cpu.sv` — self-checking program, illegal-opcode test,
   directed ALU and address tests, decode spot checks.
7. `formal/` — exhaustive combinational proofs (ALU, address), PSW field
   isolation proof, core retirement-contract BMC and covers.
8. `report/2026-11-05-m1-core.md` — measured results and limits.

## Design decisions and why

- **Sequencer, not microcode.** The M1 core is a conventional multi-cycle
  sequencer. Historical machines were microcoded or hardwired; reproducing
  either belongs to a model milestone with microcode evidence (#388), not to
  the shared architectural engine.
- **One instruction at a time.** No overlap or prefetch, so every retirement is
  observable and the retirement trace can be checked exactly. Timing is out of
  scope and must not be inferred from cycle counts.
- **Byte-at-a-time fetch.** The simplest correct fetch over a word-wide storage
  port. It costs cycles, not correctness; an instruction-fetch buffer belongs
  with the storage timing milestone.
- **Explicit illegal-instruction halt.** Silently treating an unknown opcode as
  a no-op would hide decode bugs; halting makes them visible and testable until
  program interruptions exist (#385).
- **Definition header instead of a package.** The Yosys 0.69 SystemVerilog
  frontend rejects `import pkg::*` inside a module, and the formal flow depends
  on Yosys. Module-scope inclusion keeps one definition file for both tools.

## Next increments (in order)

1. **Interruptions and PSW swapping** (#385): program-check codes, old/new PSW
   areas at `0x00`-`0x7F`, mask handling, `LPSW`/`SSM`, wait and problem state.
   This removes deviations 1-5 in `spec/spec.md`.
2. **Storage timing** (#384 follow-up): registered read, storage access cycles,
   and the fetch buffer; then instruction timing can be compared with A22-6825.
3. **Remaining instruction groups**: halfword, shift, multiply/divide, decimal,
   SS moves and compares, `EXECUTE`, `TR`/`TRT`/`ED`.
4. **Protection and DAT** (#385, #398): storage keys, protection exceptions, and
   the Model 67 address translation.
5. **Channels and IPL** (#386), then peripherals (#404-#408), then Model 30 (#393).

## Risks

| Risk | Mitigation |
|---|---|
| Shared misreading of the manual (no external oracle yet) | Issue #383 must provide an independent emulator and corpus; until then no compatibility claim is made. |
| Formal depth is shallow (12 cycles) | Properties are stated one instruction at a time; induction and covers supplement BMC; deeper proofs need abstraction or a smaller state space. |
| Model deviations leak into the shared engine | Model folders own their deviations; the shared engine may only implement what the model matrix proves is common. |
| Copyright of historical media | Nothing is redistributed; downloads stay in ignored `work/` with a manifest; rights are checked before any test depends on them. |
