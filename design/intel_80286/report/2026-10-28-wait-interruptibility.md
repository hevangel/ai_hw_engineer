# 80286 interrupts while WAIT is stalled

Date: 2026-10-28 15:32 UTC  
Status: functional real-mode NMI/INTR entry is implemented during WAIT's BUSY stall. The saved return IP remains an explicit assumption.

## Source review

Playwright CLI inspection of Intel's *1983 Microprocessor and Peripheral
Handbook*, iAPX 286/10 Chapter 4, Table 1 (printed page 4-3), found the
statement: “The 80286 may be interrupted while waiting for BUSY to become
inactive.” The handbook also says BUSY and ERROR are asynchronous to the
system clock. The same table describes BUSY becoming inactive as HIGH, which
conflicts with Intel 210760-002 Chapter 6 and the 80287 data sheet. This change
uses the later, matching hardware-manual and data-sheet evidence for BUSY
polarity; the handbook is cited here only for interruptibility.

The same handbook's “Processor Extension Transfers” section (printed page
4-31) identifies reserved ports `00F8h`, `00FAh`, and `00FCh`. For each memory
operand, it describes a word transfer at `00FAh` and one or two memory bus
operations, with three operations for an odd-address word. It still does not
give the per-ESC command byte sequence or port order, so successful ESC
transactions remain unimplemented.

Source: [Intel 1983 Microprocessor and Peripheral Handbook, Bitsavers scan](https://bitsavers.org/components/intel/_dataBooks/1983_Intel_Microprocessors_and_Peripherals_Handbook.pdf).

## Implementation

The event controller now receives an eligible boundary while the core is in
`WAIT_BUSY` for opcode `9Bh`. Once NMI or an IF-enabled INTR has been selected,
the WAIT state starts normal event delivery without retiring WAIT. INTR still
uses the acknowledge transaction; NMI does not. The feature is limited to
WAIT; ESC's separate BUSY stall is unchanged.

**ASSUMPTION A25:** an event accepted during WAIT saves the already-advanced
IP, so IRET resumes at the instruction after WAIT. The handbook establishes
that interrupts can occur but does not specify the saved IP for this case.
The regression holds BUSY high through the interrupt handler and IRET to make a
restart at WAIT observable. This verifies the selected behavior inside this
implementation; it is not an independent 286 oracle. Keep A25 open for an
independent primary-source statement, native trace, or historical software
validation before sign-off.

## Verification

The runner was built with Verilator 5.052 and strict `-Wall` flags. Its exact
source/tool fingerprint is
`db8e315bfb83a4ae344d21b8a2deedca0fe4dcc1f6eea368f1e358103b2575d0`. The
runner's full source hashes are captured in
`work/wait_interrupt_20261028/sim/build_manifest.json`.

- `Vintel_80286 --processor-extension`: PASS. Covers NMI and INTR during a
  sustained BUSY stall, exact event frames, acknowledgement behavior, no
  fabricated WAIT retirement, IRET to the selected successor, and existing
  WAIT BUSY/ERROR plus ESC #NM/#MF cases.
- `Vintel_80286` with no arguments: full default bootstrap PASS, 58 lines.
  This includes the general real-mode and protected-mode event matrices and
  all existing default checks.

Commands run inside the project container:

```sh
INTEL_80286_WORK_DIR=/work/design/intel_80286/work/wait_interrupt_20261028 \
  sh scripts/build_runner.sh
/work/design/intel_80286/work/wait_interrupt_20261028/sim/Vintel_80286 --processor-extension
/work/design/intel_80286/work/wait_interrupt_20261028/sim/Vintel_80286
```

Evidence is retained under `work/wait_interrupt_20261028/`:

| Artifact | SHA-256 |
|---|---|
| Focused processor-extension log | `6a15bcb2791e928ac77f45e2aa17c282cb4a4762b337a7e0b366fbca60646885` |
| Full default bootstrap log | `6e8e3eab5bfe50f8a821377cc88a703a01a83f8d659592d2d0672458c469e873` |
| Build manifest | `a7cc5998e500ff2b0aa6c330f490b849997950b1098353aa4c9c59252383ec97` |
| Runner binary | `7e643d710acc7fc44f90dca76eddf659e86c44feac4b467609612436feaa7ec4` |
| `src/intel_80286.sv` | `251de2323706b0372c112c8ba26f8d4de4eb41a0d0bc493ad7a8a7867d1f2189` |
| `tb/bootstrap.cpp` | `100777ef6a87f2d6cd190017a52f53932d324cd34178a5628dcc80e64b4b27f7` |
| `spec/interrupt_execution.md` | `4fad8fa9008e17ba84177f62a18b53aed868cc2fafd99b06f0d8cc4d83414776` |

The protected-mode WAIT regression was added at the 15:54 UTC checkpoint; see
the [protected WAIT report](2026-10-28-protected-wait-interruption.md). Nativepin timing, ESC interruptions, TF behavior while WAIT is stalled, simultaneous
BUSY deassertion and interrupt selection, and independent confirmation of A25
remain open. The active whole-core PDR uses an earlier source snapshot and
does not prove this change; current-source connected-core proof and the full
release gate remain open.

The issue checkpoint is [comment 6473353919](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6473353919).
