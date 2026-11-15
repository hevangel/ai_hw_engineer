# IBM PC AT 5170 test plan

Status: M1 checks exist (`scripts/run_post.sh`, `scripts/run_synth.sh`,
`scripts/run_all.sh`). M2 adds the 8042 reference-model check, the extended
Unicorn oracle and three BIOS checkpoints. M3 adds the MC146818
reference-model check and extends the Unicorn oracle to protected mode,
hardware interrupts and processor resets.

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
    CPU read. Result: no-wait scenario, 559,555 8042 instructions and
    39,267 CPU reads identical; wait-state scenario, 737,730 instructions
    and 28,966 reads identical; data replies 55h and FFh.
  - The Unicorn instruction oracle (`scripts/check_post_trace.py` via
    `design/intel_80286/scripts/bios_replay.py`) is extended to the string
    instructions, SGDT/SIDT/LGDT/LIDT and SMSW that the BIOS uses after the
    8042 test. Result: 1,125,813 instruction states and data transfers
    (1,084,662 with wait states) match Unicorn up to `F000:068B`. Two values are not compared
    because Unicorn models a later CPU: MSW bits 4–15 returned by SMSW and
    the unused sixth byte stored by SGDT/SIDT.
  - Three new BIOS checkpoints in `check_post_trace.py`: "8042 self-test
    reply 55h" (`F000:03DB` falls through to `03DD`), "8042 command byte
    accepted" (`F000:03F7` to `03FE`) and "8042 test complete"
    (`F000:0402` to `0422`).
  - Both bus-timing scenarios used in M1 (no wait states with timer
    half-period 8; wait states with half-period 11) run.
- M3 (done): both scenarios stop at `F000:1453`, a read of port 1F7h at
  POST checkpoint 3Ch, with 3 CPU resets and 8 interrupt-acknowledge cycles
  (4 interrupts, vector 08h). The BIOS's protected-mode memory test runs
  with no expansion memory and returns through the 8042 reset. Checks:
  - 8042 against the UPI-42 reference model (`scripts/check_kbc_log.py`),
    again over the longer run. No-wait scenario: 7,777,553 8042
    instructions and 1,648,422 CPU reads identical. Wait-state scenario:
    10,543,228 instructions and 1,637,225 reads identical. Data replies
    55 FF FF 02 FE 00; 19 host writes.
  - `scripts/check_rtc_log.py` (new). The runner logs every MC146818
    address strobe, data write and data read with the number of oscillator
    periods the chip had counted, and every byte the CPU read from port
    71h. The script replays them from the same power-on image into
    `design/motorola_mc146818/scripts/mc146818_model.py`. No-wait scenario:
    22,855 address strobes, 23 writes and 22,830 CPU reads identical over
    1,196,105 oscillator periods (36.5 s of clock time; the clock reads
    12:00:37 at the end, having started at 12:00:00). Wait-state scenario:
    14,538 strobes, 23 writes and 14,513 reads identical over 1,622,090
    periods (49.5 s; 12:00:50). This removes the M2 limit that the
    MC146818 was checked only by the BIOS's own tests.
  - Unicorn: the replay is extended to protected mode, hardware
    interrupts, exceptions and processor resets. Result: 16,688,169 and
    16,586,155 instruction states and data transfers match up to
    `F000:1453`, with 4 hardware interrupts, 4 exceptions, 69 software
    interrupts and 3 resets followed and no instruction skipped. Not
    judged, because Unicorn models a later CPU: the 1,187 descriptor
    accessed-bit writes (compared separately), the undefined AF bit in 3
    pushed flag images, MSW bits 4-15 (3 times) and the SGDT/SIDT sixth
    byte (6 times). Unicorn does not check segment limits on accesses that
    do not fault, so a fault the RTL failed to raise would not be caught.
    `check_post_trace.py` now requires all 13 of its BIOS checkpoints.
  - The trace gains `A` (interrupt-acknowledge) and `Z` (processor reset)
    records; the STOP line reports `open_reads`, `open_writes`,
    `cpu_resets` and `inta_cycles`.
  - Not checked against an independent model: the 8259s (only the BIOS's
    own tests and the vectors and in-service values seen).
  - Each scenario simulates in about 8 to 10 minutes.
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
