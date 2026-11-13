# IBM PC AT 5170 test plan

Status: planned. No checks exist yet.

## Oracles

| Oracle | Use | Limits |
|---|---|---|
| Unicorn 2.1.4 | Instruction-by-instruction CPU state for real-mode BIOS code, with captured I/O reads replayed | Not a device or timing oracle |
| PCE-286 oracle loop (`design/intel_80286/plans/pce_oracle_loop.md`) | Protected-mode CPU rules | No interrupts, NMI or single-step yet |
| 86Box (`external/86box`, GPL, built and run as a separate program) | Whole-machine checkpoints: port 80h values, I/O order, screen text, boot result | Emulator, not hardware; disagreements are classified, not assumed RTL bugs |
| PCjs 5170 machine | OS/2 1.0 + CPGREP baseline | Profile differs from REV1 (decision D1) |

## Checks by milestone

- M1: BIOS trace to the 8042/CMOS boundary; Unicorn agreement for every
  instruction; same I/O write order as 86Box up to that point; standalone
  tests for each promoted board module still pass.
- M2: 8042 and CMOS chip regressions in their own design folders; BIOS
  protected-mode memory test passes and returns through the 8042 reset.
- M3: POST completes with no error text; screen text matches 86Box;
  keyboard input reaches the BIOS buffer; diskette read through DMA.
- M4: PC DOS boot, DIR, file write and readback, reboot and readback.
- M5: OS/2 1.0 prompt and the CPGREP output line.

## Every milestone

- `verilator --lint-only -Wall` on system RTL.
- Synthesis with Yosys.
- Formal checks for new board logic where it has a clear contract
  (bus ownership between CPU, DMA and refresh; A20 masking).
- A firmware run never patches the BIOS or intercepts interrupts.
