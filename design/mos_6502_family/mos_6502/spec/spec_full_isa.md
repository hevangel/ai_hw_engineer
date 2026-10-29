# MOS 6502 — Full Instruction Set (stage 2) — Specification

## 1. What this stage is

Stage 1 of `design/mos_6502_family/mos_6502` implemented a 29-opcode subset ("functionally
sequenced, not bus-cycle accurate", per the stage-1 spec) with an Apple II
keyboard-echo test. This stage **completes the documented NMOS 6502
instruction set** — all 151 documented opcodes, every documented addressing
mode, the stack operations, BRK/RTI, and level/edge interrupt inputs — so
that the planned `system/apple_iie` build can run real 6502 firmware on the
reconstructed chipset.

Everything outside the instruction set remains as stage 1 left it, and the
same explicit assumptions carry forward.

## 2. Independent oracle (repo CPU rule)

Per the repo's CPU escaped-defect rules, the reference model is an
**external artifact**, not a re-reading of the RTL:

- **ISS oracle**: [py65](https://github.com/mnaberez/py65) `MPU`
  (`py65/devices/mpu6502.py`, BSD-3-Clause), vendored at
  `references/py65_mpu6502.py` (+ its two utility modules). The regression
  generator **imports the vendored file** and pre-computes expected
  per-instruction state vectors; the testbench replays them against the
  RTL. The RTL is never consulted when producing the vectors.
- **Real-software regression**: Klaus Dormann's
  [6502_functional_test](https://github.com/Klaus2m5/6502_65C02_functional_tests)
  (GPL-3; binary vendored at `references/6502_functional_test.bin`, upstream
  link recorded here per GPL). The standard build loads at `$0000` with the
  program entry at `$0400` (the `bin_files` distribution's `... = $0400`
  configuration; entry defined by the test's `lp` symbol published in the
  repository as $0400 for the prebuilt binary). Success is signaled by the
  test trapping into a tight `JMP *` loop after printing "PASSED" through
  its trap mechanism: the documented success signature is the program
  reaching `jmp *` with the checksum-free final state — concretely, the
  run detects the infinite self-loop at the success trap address and
  reports the final PC. Any test failure traps to `bra error` loops whose
  addresses are printed on the console via the test's own character output
  — with no console the run fails by watchdog timeout instead.

  Both regressions run in `scripts/run_all.sh` per the repo rule.

## 3. Instruction-set contract

All 151 documented NMOS 6502 opcodes, by group:

- **ALU group (opcode[1:0] = 01)**: ORA, AND, EOR, ADC, STA, LDA, CMP, SBC
  across (imm), zp, zp,X; abs, abs,X, abs,Y; (zp,X), (zp),Y.
- **RMW group (10)**: ASL, LSR, ROL, ROR, STX, LDX, DEC, INC across modes;
  TXA/TAX/TXS/TSX/TAY/TYA, and the accumulator shifts.
- **Control group (00)**: BIT, JMP (abs + the documented indirect
  page-wrap bug), JMP (ind), STX/LDX (zp,y / abs,y), branches
  (BPL/BMI/BVC/BVS/BCC/BCS/BNE/BEQ), flag ops (CLC/SEC/CLI/SEI/CLV/CLD/
  SED), stack (PHA/PHP/PLA/PLP), JSR/RTS, BRK/RTI, NOP.
- **Flags**: full N V – B D I Z C semantics, including NMOS decimal-mode
  ADC/SBC flag behavior (N/V/Z from the binary result, C from the decimal
  result — the NMOS "invalid flags" quirk, matching py65).
- **Interrupts**: `irq_n` (level-sensitive, masked by I) and `nmi_n`
  (edge-triggered), sampled at instruction boundaries; vector pushes as
  documented (BRK pushes PC+2 with B=1; IRQ pushes with B=0).

## 4. Bus and timing contract (unchanged from stage 1, restated)

- One bus transfer per `clk` (one CPU cycle per clock); reads are
  combinational (`bus_data_i` valid in the same cycle the address is
  presented); `bus_we` pulses with `bus_data_o` for one cycle on writes.
- `fetch_o` marks opcode-fetch cycles; `pc_o`, `status_o`, `x_o`, `y_o`
  remain for verification; `fault_o` fires only if the decoder meets an
  undocumented opcode (all 256-decode coverage asserted in the TB).
- **ASSUMPTION (carried from stage 1)**: no dummy reads/writes, no
  page-cross cycle penalties, no read-modify-write double-write cycles.
  The core is instruction-accurate, not cycle-accurate. The Apple IIe
  chipset reconstruction (MMU/IOU) is cycle-level in the same sense, and
  the system build must not rely on sub-instruction bus timing. Exact NMOS
  cycle timing remains future work gated on the MOS hardware manual.
- **ASSUMPTION**: reset is the stage-1 synchronous vector fetch (`$FFFC`/
  `$FFFD`), not the NMOS 7-cycle sequence.
- **ASSUMPTION**: R/W register initialization at reset is
  A=X=Y=0, P=$24 (stage-1 convention); NMOS reset leaves them
  indeterminate.

## 5. Verification plan (summary; details in plans/)

1. **ISS vector regression** (the primary gate): a generator script loads
   directed programs + the vendored test binaries into py65, executes, and
   emits a compressed expected vector stream (per instruction: PC, opcode,
   A/X/Y/P/S, bus addr/we/data of each access). The TB drives the RTL with
   the same memory image and compares every vector. Programs cover: every
   opcode × every documented mode at least twice (zero/non-zero, carry/
   no-carry, decimal/binary, page-cross/no-page-cross), the JMP indirect
   page-wrap, stack underflow/overflow addresses, and interrupt sequences.
2. **Klaus functional test**: full binary, RTL executes from reset;
   success detection as in §2.
3. **Formal**: decode completeness (no documented opcode reaches FAULT),
   flag-equivalence spot properties, branch arithmetic bounded checks.
4. Coverage/synthesis per the standard flow.

## 6. Assumption ledger (stage-2 additions)

- **A11 (instruction timing)**: as §4 — instruction-accurate,
  not cycle-accurate; no dummy cycles; RMW reads once, writes once.
- **A12 (interrupt sampling latency)**: interrupts are recognized at
  instruction boundaries only; mid-instruction NMOS sampling detail is
  not modeled.
- **A13 (decimal mode source)**: NMOS decimal ADC/SBC implement the
  canonical NMOS algorithm (Bruce Clark's real-hardware-validated
  formulation, including the N/V/Z-from-binary quirk). The vendored py65
  oracle deviates from real hardware in decimal-SBC corner cases; the
  generator overrides it with the same canonical algorithm. py65 is
  otherwise used as-is: an earlier revision additionally remapped opcode
  $D1 to `SBC (zp),Y` as an "oracle correction"; that was a misreading of
  the NMOS opcode matrix ($D1 is `CMP (zp),Y`; `SBC (zp),Y` is $F1), it
  escaped the vector replay because generator and RTL were changed
  together, and Klaus's functional test caught it — see
  `failure_notes/2026-10-13-mos6502-d1-cmp-zpy.md`.
- **A14 (JMP indirect bug scope)**: only `JMP ($xxFF)` page wrap is
  modeled; there are no other undocumented behaviors.
- **A15 (fault_o contract)**: `fault_o` remains a development diagnostic
  for the 105 undocumented opcodes; the TB asserts it never fires on
  documented code.
