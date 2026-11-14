# IBM PC AT 5170 implementation plan

Status: M1 done and merged (board skeleton, stops at the first 8042
read). M2 (8042 and MC146818 on the board) is in progress; decision D3 is
resolved (Option A, below).

Each milestone ends with a report in `report/` and an update to issue
https://github.com/hevangel/ai_hw_engineer/issues/254. A milestone is done
only when the unchanged BIOS or software reaches its stated point on the
RTL, matching an independent machine. `scripts/expected_stop.txt` records
the current boundary; moving it needs a report.

## M0: scaffold and sources (done)

- System folder, specification, plans and index entry.
- Remaining sourcing (needed before M2/M3 RTL): system I/O map, 8042
  commands and output port, CMOS map and shutdown byte, NMI mask, type-1
  CPU clock, exact announcement date.
- The 8042 firmware is sourced since M2: IBM part 1503033, rebuilt and
  hash-verified (see M2).

## M1: board skeleton with strict decoding (done)

- `src/ibm_pc_at_5170.sv` composes the native 286 with the 286 design's
  schematic-cited AT models (timer, port 61h, refresh path, two 8237
  register interfaces, page registers and refresh page map, RAS trigger),
  reused in place.
- `tb/post_runner.cpp` supplies 640K RAM and the ROM aliases and stops at
  the first unmodeled I/O or memory access. `scripts/run_post.sh` checks
  the stop point and compares every instruction with Unicorn.
- Result: the BIOS stops at `F000:00DE`, its cold-boot read of the 8042
  status register, after 30 instructions. The plan's earlier order (8259s
  before the 8042) was wrong: the BIOS reads the 8042 before any other
  board device. See [the M1 report](../report/2026-11-13-m1-board-skeleton.md).

## M2: 8042 and MC146818 on the board (in progress)

On the strict board the unchanged REV1 BIOS does the following, in order:

1. Reads the 8042 status at `F000:00DE`. It reads F0h: system-flag bit 2 is
   0, so this is a cold boot.
2. At `F000:01AF` writes 8Bh to port 70h and at `F000:01B3` reads port 71h
   (RTC status register B), then runs a read/write test of CMOS shutdown
   byte 0Fh at POST checkpoint 02. It halts at `F000:01AD` if that fails.
3. Writes ports 3B8h and 3D8h once each.
4. Runs the timer, DMA, page-register and refresh tests.
5. Runs its 8042 test at `F000:03A2`–`0422` (AAh gives 55h, C0h reads the
   input port, then the 60h/5Dh command byte).
6. Continues to POST checkpoint 12h and stops at `F000:068B` on a write to
   port F1h (math-coprocessor reset), just before it initializes the 8259s.

So M2 needs the MC146818 as well as the 8042. This corrects the earlier
split, which put the 8042 in M2 and CMOS in M3.

Done so far:

- The board top composes the native 80286 (`intel_80286_native_cpu`)
  directly, not through the 286 design's
  `intel_80286_at_refresh_timer_native` fixture wrapper, so the board owns
  CPU reset, INTR and NMI. The timer, port 61h, DMA, page-register and
  refresh modules are still the 286 design's AT models, reused in place.
- Decision D3 is resolved as Option A: the Intel 8042 (U126,
  `design/intel_mcs48/intel_8042`) is an MCS-48/UPI-42 core running IBM's
  firmware part 1503033. The ROM image is rebuilt and hash-verified by
  `design/intel_mcs48/intel_8042/scripts/rebuild_1503033.py` (SHA-1
  `0100f8789fb4de74706ae7f9473a12ec2b9bd729`, matching MAME's
  `1503033.bin`) into an ignored work folder.
- 8042 wiring from the Technical Reference (host bus, chip select through
  U123 and U115, P20 to CPU reset, P21 to A20, P24 to IRQ1, keyboard
  clock and data, input port, 6 MHz clock stepped once per 15 processor
  clocks) is recorded in the spec. P20 resets only the 80286.
- Port 70h is a write-only latch: bit 7 NMI mask, bits 6–0 RTC/CMOS
  address. A read of port 70h is unclaimed.
- An M1 defect is fixed: the board's "undriven read" flag fired during the
  wait states of a read whose device had not yet driven data; it is now
  checked when the read completes.

To do:

- Put the MC146818 on the board. It is being built as its own design,
  `design/motorola_mc146818` (issue originally
  hevangel/ai_engineer#121). Port 70h write is the address strobe, port 71h
  is the data strobe, and its IRQ goes to interrupt request 8, not
  connected until the 8259s exist (M3).
- Replace the bare 64-byte RAM that stands in for the MC146818 in the
  experiment below with the real design, and record final results.

Goal: with the 8042 and MC146818 on the board, the unchanged BIOS runs to
its first access to hardware not on the board, expected at `F000:068B`
(write to port F1h, POST checkpoint 12h), about 1.1 million instructions,
passing its own 8042 test on the way. Results so far are provisional: they
come from an experiment with a bare 64-byte RAM standing in for the
MC146818. The final instruction count is `PENDING-M2-RESULT`.

## M3: coprocessor ports, interrupt controllers and memory

- Math-coprocessor ports F0h/F1h.
- Two cascaded 8259s with INTR and INTA wired to the CPU; MC146818 IRQ to
  interrupt request 8.
- Wire the 80286 shutdown cycle to CPU reset through the U105/U106
  flip-flops (sheet 22), replacing the stand-in of assumption AT7. The
  BIOS reads the shutdown byte at `F000:00E7` on the warm-restart path.
- Expansion RAM above 1 MB and the protected-mode memory test.

## M4: video, keyboard input and diskette; full POST

- Video adapter per decision D2. Extract the CGA from the PC system into a
  reusable module rather than copying it.
- Keyboard scan codes from the host through the 8042.
- AT diskette adapter with the 8272.
- Goal: POST completes and the BIOS attempts to boot. Web panel and
  waveform screenshot in the README.

## M5: PC DOS

- Boot PC DOS from diskette, run DIR, write and read back a file.
- AT fixed-disk controller at 1F0h (new design), then boot from it.

## M6: OS/2 1.0 and CPGREP

- Settle decision D1 and memory size.
- Boot MS OS/2 1.0 and run `CPGREP -yn fast ..\README`. Compare with the
  PCjs baseline.
- Any 286 defect found here is an escaped defect: failure note, fix in
  `design/intel_80286`, and a new PCE oracle scenario or directed test.

## Risks

- The decode PROM U115 is unpublished (assumption AT8), so the 8042's
  address aliases are inferred, not read from the PROM.
- The 286 has no oracle yet for interrupts, NMI and single-step in
  protected mode. OS/2 depends on all three; extend the PCE oracle loop
  before M6.
- Simulation speed: OS/2 boot is hundreds of millions of instructions.
  M1 runs about 12 cycles per instruction; measure host speed once the
  BIOS runs longer and plan checkpointing if needed.
