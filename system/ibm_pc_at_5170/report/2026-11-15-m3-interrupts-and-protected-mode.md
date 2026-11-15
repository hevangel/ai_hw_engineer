# M3: interrupts, coprocessor ports and shutdown reset — 2026-11-15

## Result

With the two 8259A interrupt controllers, the math-coprocessor ports and the
shutdown-to-reset path on the board, the unchanged IBM AT REV1 BIOS
(01/10/84) runs 16,688,169 instructions of its power-on self-test
(16,586,155 with bus wait states) and stops at `F000:1453`, a read of port
1F7h (fixed-disk status) at POST checkpoint 3Ch. No fixed-disk adapter is
fitted, and a read from an empty expansion slot still stops the run. M2
stopped at `F000:068B` after 1,125,813 instructions. Nothing boots.

| Check | Command | Result |
|---|---|---|
| Lint | `scripts/run_post.sh` (first step) | Clean, `verilator --lint-only -Wall` |
| BIOS stop point, no wait states | `scripts/run_post.sh` | `F000:1453`, port 1F7h read, POST 3Ch; 16,688,169 instructions |
| BIOS stop point, wait states | `scripts/run_post.sh` | Same stop; 16,586,155 instructions |
| Resets and interrupts, both scenarios | `scripts/run_post.sh` | 3 CPU resets; 8 interrupt-acknowledge cycles (4 interrupts, vector 08h) |
| 80286 against Unicorn | `scripts/run_post.sh` | Every instruction state and data transfer matches: 16,688,169 and 16,586,155 instructions, through protected mode, 4 hardware interrupts, 4 exceptions, 69 software interrupts and 3 resets; 13 of 13 BIOS checkpoints |
| 8042 against the UPI-42 reference model, no wait states | `scripts/run_post.sh` | 7,777,553 8042 instructions and 1,648,422 CPU reads identical |
| 8042 against the UPI-42 reference model, wait states | `scripts/run_post.sh` | 10,543,228 instructions and 1,637,225 reads identical |
| MC146818 against its reference model, no wait states | `scripts/run_post.sh` | 22,855 address strobes, 23 writes and 22,830 CPU reads identical over 1,196,105 oscillator periods |
| MC146818 against its reference model, wait states | `scripts/run_post.sh` | 14,538 strobes, 23 writes and 14,513 reads identical over 1,622,090 periods |
| Synthesis | `scripts/run_synth.sh` | Pass, 87,161 generic cells, `check -assert` clean; the only latch is the refresh arbiter's schematic latch |

Each scenario simulates in about 8 to 10 minutes and its Unicorn replay
takes about 20. `run_post.sh` takes about 54 minutes from a clean work
folder in the `ai-hw-engineer` image; synthesis takes about 12 more.

## What changed on the board

- Two 8259As on sheet 16: master U114 (SP/-EN pulled up by RN5) and slave
  U125 (SP/-EN grounded), CAS0–CAS2 wired pin to pin, the slave's INT on
  master IR2 and the master's INT straight to the 80286 INTR pin. The
  selects come from U123 on sheet 13: -INTR1 CS for 020h–03Fh and
  -INTR 2 CS for 0A0h–0BFh. A0 of each chip is XA0, so each answers
  throughout its 32-address block. -INTA comes from the 82288 (sheet 2) to
  both chips, and the vector returns through U113 (sheet 13) and the normal
  data-bus read path. Requests: master IR0 = 8254 OUT0 (a direct wire),
  IR1 = +OPT BUF FULL from the 8042, IR3–IR7 = I/O channel IRQ 3–7; slave
  IR0 = IRQ 8 from the MC146818 (through U107), IR1–IR4 = IRQ 9–12,
  IR5 = IRQ 13 from the coprocessor PAL, IR6–IR7 = IRQ 14–15. The 8259
  design reused is `design/intel_8259`. Assumptions AT13 and AT16.
- Math-coprocessor ports, sheet 3: U123 selects 0E0h–0FFh (-CS287) and
  PAL16L8A U130 decodes it with XA3, XA0 and -XIOW into the busy-latch
  clear (port F0h), +RESET 287 (port F1h), -NPCS, -BUSY 286 and IRQ 13. No
  80287 is fitted: -BUSY and -ERROR are pulled up, IRQ 13 stays inactive,
  both writes have no effect and reads are not decoded. Assumption AT17.
- Shutdown, sheet 22: U84 decodes the 80286 shutdown cycle and clocks
  flip-flop U105, which resets the processor through the same -SHT DWN net
  as the 8042's RC line. Only the 80286 is reset. This replaces the "not
  wired yet" part of assumption AT7.
- I/O bus conversion: every device on the system board is 8 bits wide. The
  board holds the processor not ready during a word I/O cycle and gives the
  devices two byte cycles, the even address with the low byte, then the odd
  address with the high byte. The BIOS depends on it at `F000:0C9A`.
  Assumption AT15.
- NMI is still not connected to the processor. On sheet 3, NMI is
  (I/O-channel-check latch OR parity latch) AND NOT the mask flip-flop
  U118. With no parity logic and no I/O channel check modeled, neither
  source can be active, and U118 is preset by reset, so NMI is disabled at
  power-up, which agrees with assumption AT9.
- Memory outside the 640K RAM and the ROM is unpopulated: a data read
  returns FFh, a write is ignored, and both are counted (AT14).
- The POST runner (`tb/post_runner.cpp`) changed in these ways: the
  unpopulated memory rule; a halt ends the run only after 2,000,000
  processor clocks with interrupts disabled, because the BIOS halts while
  it waits for the 8042's reset pulse; a shutdown no longer ends the run;
  the trace gains `A <byte>` records (interrupt-acknowledge cycles; the
  second of each pair carries the vector) and `Z` records (processor
  reset); the STOP line reports `open_reads`, `open_writes`, `cpu_resets`
  and `inta_cycles`; and an optional MC146818 log is written.
- Each connection is cited to the March 1984 Technical Reference logic
  diagrams (sheets 1, 2, 3, 11, 13, 16, 19, 20, 22) in the
  [specification](../spec/spec.md), with new assumptions AT13–AT17 and
  updated AT7.

## What the BIOS did between the two stop points

- Wrote port F1h, then initialized both 8259s: master ICW1 11h, ICW2 08h,
  ICW3 04h, ICW4 01h; slave ICW1 11h, ICW2 70h, ICW3 02h, ICW4 01h; then
  masked both with FFh.
- Entered protected mode and ran POST checkpoints 13h–1Dh. Sized memory
  above 1 MB by writing AA55h to each 64K block and reading it back
  (routine HOW_BIG1, printed pages 5-46 and 5-47); it found none.
- Wrote FEh to port 64h so that the 8042 pulses the CPU reset line, and
  halted until the reset arrived. Three such resets happen in the run.
- Back in real mode, tested the 8259 mask registers (wrote 00h and FFh and
  read them back), checked for unexpected interrupts with interrupts
  enabled, wrote page registers 82h and 83h with one word `OUT 82h,AX` at
  `F000:0C9A` and read each byte back (checkpoint 27h), and tested timer
  channel 2.
- Unmasked IRQ 0 and took four timer interrupts (vector 08h). It read the
  in-service register as 01h and sent end-of-interrupt 20h.
- Ran further protected-mode tests (checkpoints F0h–FAh).
- Exercised the 8042: keyboard disable and enable (ADh, AEh), test inputs
  (E0h gives 02h), keyboard reset (FFh on the data port gives FEh, because
  no keyboard is attached), interface test (ABh gives 00h), command bytes
  4Dh and 45h, and D1h with DDh, which closes the A20 gate.
- Read the MC146818 many times: register A was polled 22,748 times in the
  no-wait scenario while the BIOS waited for the update-in-progress bit,
  plus the configuration bytes.
- Wrote the video ports 3B4h, 3B5h, 3B8h, 3B9h, 3D4h, 3D5h, 3D8h and 3D9h
  and video memory (no adapter: 183 empty-slot writes and 45,914 writes to
  unpopulated memory), wrote diskette ports 3F2h and 3F7h, then read 1F7h.

## How the new parts are checked

- **8042.** Unchanged from M2: `scripts/check_kbc_log.py` replays the
  logged accesses into the UPI-42 reference model running the same
  firmware. Over the longer run the model retires the same instructions and
  gives the same CPU reads in both scenarios (table above). The data
  replies are 55 FF FF 02 FE 00 and there are 19 host writes.
- **MC146818.** New in M3. The runner logs every address strobe, data write
  and data read with the number of oscillator periods the chip had counted,
  and every byte the CPU read from port 71h. `scripts/check_rtc_log.py`
  replays them from the same power-on image into
  `design/motorola_mc146818/scripts/mc146818_model.py` (written from the
  Motorola data sheet, not from the RTL) and requires every byte the CPU
  read to equal the model's value. The no-wait run covers 36.5 s of clock
  time (the clock reads 12:00:37 at the end, having started at 12:00:00);
  the wait-state run covers 49.5 s (12:00:50). This removes the M2 limit
  that the MC146818 was checked only by the BIOS's own tests.
- **80286.** The Unicorn replay now follows protected mode, hardware
  interrupts, exceptions and processor resets. Interrupt and exception
  entry is executed by Unicorn itself, and every vector read, stack write
  and handler address must match; a reset keeps memory and must be
  followed by the reset-vector jump. Both runs match on every instruction
  and no instruction is skipped. Followed in each run: 4 hardware
  interrupts, 69 software interrupts, 3 resets and 4 exceptions (two BOUND
  faults at `F000:1D3B` and `1D5F`, and two general-protection faults at
  `F000:1CAC` and `1E02` that Unicorn does not raise; the replay applies
  the 286 segment rule to Unicorn's own segment cache and the error code
  and pushed address agree with the RTL). The checker itself was tested by
  corrupting a protected-mode register value, an interrupt's stack push
  and a post-reset record in copies of the trace; each was caught at that
  record. The 286 design's two AT BIOS fixture regressions give identical
  traces before and after the change. `check_post_trace.py` now requires
  all 13 of its BIOS checkpoints.
- **8259s.** Checked only by the BIOS's own tests passing and by the
  vectors and in-service values seen (four interrupts, vector 08h,
  in-service 01h). Their accesses are not replayed into an independent
  model.

## Findings

- **Word I/O to 8-bit devices.** Without the bus conversion the BIOS failed
  its checkpoint 27h test (it read 00h from port 83h) and halted at
  `F000:0C93` after trying to print error 106. The BIOS writes both page
  registers with one `OUT 82h,AX`.
- **The schematic has no pull-ups on the data buses or the interrupt
  request lines.** Open-bus read values and idle request levels are
  therefore assumptions (AT14, AT16), not drawn facts.
- **The trace logger missed interrupt acknowledges at first.** The CPU
  model does not report them as completed data bytes; the runner now
  watches the acknowledge cycle itself.
- **The M2 limit on RC and the A20 gate is gone.** The BIOS pulses reset
  three times through the 8042 and closes the A20 gate with D1h and DDh.

## Limits

- Nothing boots. There is no video, diskette or fixed-disk adapter, no
  keyboard on the connector (the BIOS's keyboard reset gets FEh) and no
  80287.
- The 8259s are checked only by the BIOS's own tests and by the vectors and
  in-service values seen; there is no replay of their accesses into an
  independent model.
- Only IRQ 0 has been taken. IRQ 1 and IRQ 8 are connected but have not
  fired.
- NMI is not connected.
- No whole-machine comparison with an independent emulator yet.
- The A20 gate is open while the BIOS sizes memory above 1 MB and is closed
  by the last 8042 command of the run. No access above 1 MB follows, so a
  closed gate forcing A20 low has not yet been observed.
- Clocks are functional ratios, not IBM timing (AT1, AT12). The real
  shutdown reset pulse depends on SDCLK, which was not traced (AT7).
- Not judged by Unicorn, because it models a later CPU: the 1,187
  descriptor accessed-bit writes (compared separately; the RTL writes the
  bit on every load), the undefined AF bit in 3 pushed flag images, MSW
  bits 4-15 (3 times) and the SGDT/SIDT sixth byte (6 times). Unicorn does
  not check segment limits or rights on accesses that do not fault, so a
  fault the RTL failed to raise would not be caught by this check.
- No hardware interrupt has been taken in protected mode.

## Reproduce

```sh
ROM=$(sh system/ibm_pc_at_5170/scripts/get_bios.sh)
sh system/ibm_pc_at_5170/scripts/run_all.sh "$ROM"
```
