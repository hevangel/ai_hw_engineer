# IBM PC AT 5170 test plan

Status: M1 checks exist (`scripts/run_post.sh`, `scripts/run_synth.sh`,
`scripts/run_all.sh`). M2 adds the 8042 reference-model check, the extended
Unicorn oracle and three BIOS checkpoints; its final results are pending.

## Oracles

| Oracle | Use | Limits |
|---|---|---|
| Unicorn 2.1.4 | Instruction-by-instruction CPU state for real-mode BIOS code, with captured I/O reads replayed | Not a device or timing oracle; models a later CPU than the 286 (see M2) |
| UPI-42 reference model (`design/intel_mcs48/intel_8042/scripts/upi42_iss.py`) | Independent 8042 instruction stream and host-visible values, written from Intel's manual | Runs the same firmware image; does not check board wiring |
| PCE-286 oracle loop (`design/intel_80286/plans/pce_oracle_loop.md`) | Protected-mode CPU rules | No interrupts, NMI or single-step yet |
| 86Box (`external/86box`, GPL, built and run as a separate program) | Whole-machine checkpoints: port 80h values, I/O order, screen text, boot result | Emulator, not hardware; disagreements are classified, not assumed RTL bugs |
| PCjs 5170 machine | OS/2 1.0 + CPGREP baseline | Profile differs from REV1 (decision D1) |

## Checks by milestone

- M1 (done): lint; the BIOS stops at the expected boundary in both clock
  scenarios; Unicorn agrees with every instruction up to it; synthesis.
- M2: 8042 and MC146818 regressions in their own design folders; BIOS
  takes the cold-boot path at `F000:00DE`, passes its CMOS shutdown-byte
  test, passes its 8042 test at `F000:0422` and runs to `F000:068B`; the
  earlier timer, DMA, page and refresh checkpoints pass on the strict
  board. Checks added in M2:
  - `scripts/check_kbc_log.py`. The runner logs every 8042 instruction
    retired, every host write and data-register read with its position in
    the 8042's instruction stream, and every byte the CPU read from the
    8042. The script replays the accesses into the independent UPI-42
    reference model running the same firmware and requires the same
    instruction addresses in the same order and the same value for every
    CPU read. Provisional result, with a bare 64-byte RAM standing in for
    the MC146818: no-wait scenario, 559,555 8042 instructions and 39,267
    CPU reads identical; wait-state scenario, 737,730 instructions and
    28,966 reads identical; data replies 55h and FFh. Final result with
    the real MC146818: `PENDING-M2-RESULT`.
  - The Unicorn instruction oracle (`scripts/check_post_trace.py` via
    `design/intel_80286/scripts/bios_replay.py`) is extended to the string
    instructions, SGDT/SIDT/LGDT/LIDT and SMSW that the BIOS uses after the
    8042 test. Provisional result: 1,125,813 instruction states and data
    transfers match Unicorn up to `F000:068B`. Two values are not compared
    because Unicorn models a later CPU: MSW bits 4–15 returned by SMSW and
    the unused sixth byte stored by SGDT/SIDT. Final result:
    `PENDING-M2-RESULT`.
  - Three new BIOS checkpoints in `check_post_trace.py`: "8042 self-test
    reply 55h" (`F000:03DB` falls through to `03DD`), "8042 command byte
    accepted" (`F000:03F7` to `03FE`) and "8042 test complete"
    (`F000:0402` to `0422`).
  - Both bus-timing scenarios used in M1 (no wait states with timer
    half-period 8; wait states with half-period 11) run.
- M3: coprocessor-port, 8259 and shutdown-reset regressions; BIOS
  protected-mode memory test passes and returns through the 8042 reset.
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
