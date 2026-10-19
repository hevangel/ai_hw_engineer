# 6502 implementation plan

1. **Bus and reset foundation (functional subset tested):** register state, vector fetch, diagnostic fault, 29 opcodes, exact-PC tests including every branch offset at four boundary locations, and integrated Apple II keyboard echo.
2. **Core completion:** addressing modes, ALU and decimal flag, stack, branches, interrupts, read-modify-write cycles, undocumented behavior policy. Derive instruction expectations from the MOS manual and an external emulator or manufacturer trace, never from RTL.
3. **Bus accuracy:** document every cycle, dummy read/write and page crossing from the MOS hardware manual; model Apple II soft-switch side effects correctly.
4. **Verification:** independent oracle, formal invariants with reset assumptions and cover mode, opcode and cycle tests without landing padding, real historical software regression.
5. **Apple II:** wire 48 KiB RAM, keyboard and display soft switches, text video, ROM, and later graphics/storage in `system/apple_ii/`. Start with original 1977 Apple II, then document any II+ behavior separately.

Sign-off is blocked until actual Apple II firmware executes and its trace matches an independent reference. Current code is an implementation seed.

## Stage 2 record (2026-10-13, branch `design/mos-6502-full-isa`)

Delivered against the plan items:

- **Item 2 (core completion)**: full documented NMOS ISA — all 151 opcodes,
  all thirteen addressing modes, stack ops, BRK/RTI, IRQ (level, I-masked)
  and NMI (edge), binary and decimal ADC/SBC (canonical Bruce Clark
  algorithm), the `JMP ($xxFF)` page-wrap quirk, and a `fault_o` diagnostic
  for the 105 undocumented opcodes. Spec: `spec/spec_full_isa.md`.
- **Item 4 (verification)**: ISS vector regression vs the vendored py65
  oracle (770 instructions, 66,307 checks + memory-image compare, Verilator
  and xezim); SymbiYosys formal (bmc/prove/cover) with reset assumptions,
  safety properties, and full-state cover traces; real historical software
  (Klaus Dormann functional test) passing to the success trap — which is
  what caught the D1 shared-misreading escaped defect
  (`failure_notes/2026-10-13-mos6502-d1-cmp-zpy.md`). Coverage and
  synthesis run in the standard flow (`scripts/run_all.sh`).

Remaining timing work:

- **Item 3 (bus accuracy)**: instruction-accurate only — no dummy cycles,
  no page-cross penalties, no cycle-level RMW (A11); requires the MOS
  hardware manual.
Completed platform integration:

- **Item 5 (Apple II)**: [Apple II](../../../system/apple_ii/) and
  [Apple IIe](../../../system/apple_iie/) now execute historical firmware.
  The IIe runs its original ROM, keyboard-driven BASIC and 80-column slot-3
  firmware with the authored MMU/IOU/PAL. Functional CPU bus timing remains
  explicitly qualified; this does not complete item 3's pin/cycle accuracy.
