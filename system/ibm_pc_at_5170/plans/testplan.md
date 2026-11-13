# IBM PC AT 5170 test plan

Status: M1 checks exist (`scripts/run_post.sh`, `scripts/run_synth.sh`, `scripts/run_all.sh`).

## Oracles

| Oracle | Use | Limits |
|---|---|---|
| Unicorn 2.1.4 | Instruction-by-instruction CPU state for real-mode BIOS code, with captured I/O reads replayed | Not a device or timing oracle |
| PCE-286 oracle loop (`design/intel_80286/plans/pce_oracle_loop.md`) | Protected-mode CPU rules | No interrupts, NMI or single-step yet |
| 86Box (`external/86box`, GPL, built and run as a separate program) | Whole-machine checkpoints: port 80h values, I/O order, screen text, boot result | Emulator, not hardware; disagreements are classified, not assumed RTL bugs |
| PCjs 5170 machine | OS/2 1.0 + CPGREP baseline | Profile differs from REV1 (decision D1) |

## Checks by milestone

- M1 (done): lint; the BIOS stops at the expected boundary in both clock
  scenarios; Unicorn agrees with every instruction up to it; synthesis.
- M2: 8042 regressions in its own design folder; BIOS takes the cold-boot
  path at `F000:00DE` and passes its 8042 test at `F000:0422`; the earlier
  timer, DMA, page and refresh checkpoints pass on the strict board.
- M3: 8259 and CMOS regressions; BIOS protected-mode memory test passes
  and returns through the 8042 reset.
- M4: POST completes with no error text; screen text matches 86Box;
  keyboard input reaches the BIOS buffer; diskette read through DMA.
- M5: PC DOS boot, DIR, file write and readback, reboot and readback.
- M6: OS/2 1.0 prompt and the CPGREP output line.

## Every milestone

- `verilator --lint-only -Wall` on system RTL.
- Synthesis with Yosys.
- Formal checks for new board logic where it has a clear contract
  (bus ownership between CPU, DMA and refresh; A20 masking).
- A firmware run never patches the BIOS or intercepts interrupts.
