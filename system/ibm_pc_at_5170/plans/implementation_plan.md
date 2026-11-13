# IBM PC AT 5170 implementation plan

Status: M1 done (board skeleton, stops at the first 8042 read). M2 (the
8042) is next and needs decision D3.

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

## M2: 8042 keyboard controller

The 8042 is read at `F000:00DE` (system flag), and its self-test and
command-byte sequence runs at `F000:03A2`–`0422`, right after the refresh
test. The BIOS cannot get past either point without it.

- Decide D3. Option A: an MCS-48/UPI-42 core in `design/` running IBM's
  original 8042 ROM (needs a sourced, hash-pinned dump). Option B: a
  behavioral model of the host interface, which needs an independent
  oracle (86Box's AT keyboard controller, run as a separate program) and
  an assumption entry for every behavior.
- Wire the 8042 output port to gate A20 and CPU reset.
- Goal: the BIOS passes `F000:00DE` on the cold-boot path and finishes the
  8042 test at `F000:0422`. The existing fixture checkpoints (timer, DMA,
  page registers, refresh) are then re-established on the strict board.

## M3: interrupt controllers, CMOS and memory

- Two cascaded 8259s with INTR and INTA wired to the CPU.
- MC146818 CMOS (ai_engineer#121), the NMI mask at port 70h and the
  shutdown byte (read at `F000:00E7` on the warm-restart path).
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

- The 8042 needs IBM's firmware for option A; without a sourced dump it is
  a behavioral model (option B).
- The 286 has no oracle yet for interrupts, NMI and single-step in
  protected mode. OS/2 depends on all three; extend the PCE oracle loop
  before M6.
- Simulation speed: OS/2 boot is hundreds of millions of instructions.
  M1 runs about 12 cycles per instruction; measure host speed once the
  BIOS runs longer and plan checkpointing if needed.
