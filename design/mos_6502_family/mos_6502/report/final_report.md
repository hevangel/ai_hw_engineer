# MOS 6502 full-ISA — Validation Report

## Status: complete

The core implements the full documented NMOS 6502 instruction set
(151 opcodes). Every gate in the stage-2 verification plan passes:

| Stage | Result |
| --- | --- |
| `verilator --lint-only -Wall` (strict, RTL) | PASS |
| Formal: `bmc` (depth 40, bounded progress + undocumented-fault deadline) | PASS |
| Formal: `prove` (unbounded safety — fetch discipline, fault containment, interrupt-vector mux, stack addressing, B-flag push rules) | PASS |
| Formal: `cover` (all sequencer states, JMP ($xxFF) wrap, NMI/IRQ hijacks, decimal EXEC, documented fault) | PASS, no unreached covers |
| Directed vector replay (py65 oracle, 770 instructions) | PASS — 66,307 checks in Verilator and xezim, plus the full 64K memory-image compare |
| Klaus Dormann functional test (real historical software) | **PASS — success trap $3469 reached after ≈90.6M cycles** |
| Control unit test (`tb/control_test.cpp`, loads/BIT flags) | PASS |
| Yosys synthesis (`run_synth.sh`, `check -assert`) | PASS |
| Coverage (`run_coverage.sh`) | see `report/coverage_report.md` |

Reproduce with `sh design/mos_6502_family/mos_6502/scripts/run_all.sh` (lint → formal →
sim → Klaus → coverage → synth).

## Real-software regression

The Klaus Dormann `6502_functional_test` binary (reference-only,
GPL-licensed; loaded at 0 with the reset vector → $0400, 64K RAM) runs from
reset to the documented success trap. This is the design's escape hatch for
the shared-misreading class: per-instruction agreement with the ISS cannot
catch defects the oracle shares, but real 1977-era test software can.
One such defect was found and fixed in this stage — see
`failure_notes/2026-10-13-mos6502-d1-cmp-zpy.md`.

## Bugs found and fixed during this stage

1. **Decimal-SBC nibble borrow compares**: the low/high borrow tests used
   4-bit-wrapped sums, missing borrows whenever an operand nibble was $F.
   Fixed with 5-bit compares; the carry is the complement of the 9-bit
   borrow (the subtract-form bit 8 is a borrow, not a carry).
2. **IRQ pushed PC**: a hardware interrupt must push the un-executed
   instruction's address (BRK pushes opcode+2). Fixed via `brk_is_brk`
   in `S_BRK_PAD`.
3. **D1 decode misdiagnosis (escaped defect, caught by Klaus)**: an earlier
   revision "corrected" the oracle and RTL to execute `D1` as
   `SBC (zp),Y`. The NMOS opcode matrix pins `D1 = CMP (zp),Y`; py65 was
   right all along. The wrong override was applied to the generator *and*
   the RTL, so the 66k-check replay was self-consistent and blind to it.
   Klaus's `CMP ($24),Y` at $1752 exposed it. Full post-mortem with the
   prevention plan: `failure_notes/2026-10-13-mos6502-d1-cmp-zpy.md`.
4. **Klaus self-loop detector (TB)**: the watcher reset its same-PC counter
   on every non-fetch bus cycle, so it could never fire on a real trap
   loop (an operand fetch always sits between the re-fetched PCs). It now
   samples only on opcode-fetch cycles.
5. **Control unit test ported to the full-ISA contract**: the stage-1
   harness left `irq_n` undriven (Verilator C++ zero-initializes it — an
   asserted line), which the full core correctly honors: after the test's
   `CLI` every fetch was hijacked through the $FFFE/$FFFF vector. It also
   read loaded values off `bus_data_o` after completion, which the full
   RTL zeroes at fetch; the test now reads the architectural `a_o`/`x_o`/
   `y_o` ports.
6. **Yosys elaboration crash (found when formal/synth were added to the
   flow)**: the stage-1 RTL had never been through Yosys. Enum-returning
   decode functions used directly as `case` expressions hit a yosys
   unelaborated-call width-check assert (`genrtlil.cc:1369`). The decode
   calls now go through named wires (`fetch_mode`/`fetch_op`); synthesis
   and all three formal tasks pass.

## Known limitations (the assumption ledger)

See `spec/spec_full_isa.md` A11-A15: instruction-accurate, not
cycle-accurate (no dummy cycles, no page-cross penalties); interrupts
sampled at instruction boundaries; decimal ADC/SBC follow the canonical
NMOS algorithm (Bruce Clark) — py65's decimal SBC deviates from real
hardware in corner cases and is overridden in the generator; the fault_o
contract for the 105 undocumented opcodes.

## References

- `references/py65_mpu6502.py` (+ utils): the vendored BSD py65 MPU, the
  ISS oracle. Patched in exactly one documented place (decimal SBC).
- `references/6502_functional_test.a65` / `.bin.hex`: Klaus Dormann's
  functional test (GPL) — reference only, not linked into the RTL or TB
  build; the prebuilt `.bin.hex` is the simulation input.
