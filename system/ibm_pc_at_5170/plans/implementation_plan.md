# IBM PC AT 5170 implementation plan

Status: M1 done and merged (board skeleton, stops at the first 8042
read). M2 done (8042 and MC146818 on the board, stops at the first
coprocessor-port write); decision D3 is resolved (Option A, below). M3 done
(coprocessor ports, both 8259As, shutdown-to-reset and the I/O bus
conversion on the board; stops at the read of fixed-disk status port 1F7h at
POST checkpoint 3Ch). Every instruction matches Unicorn and the board
synthesizes. M4a done (I/O channel and an IBM EGA in a slot; same stop,
with a working display). M4b part 1 done (the IBM VGA card on the AT;
same stop, 720 x 400 display). The rest of M4b is next.

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

## M2: 8042 and MC146818 on the board (done)

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

Done:

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
- The MC146818 (U117, `design/motorola_mc146818`) is on the board, wired
  from sheet 18: a write to port 70h is the address strobe and loads the
  NMI mask from bit 7, port 71h is the data strobe, and its IRQ is the
  board's IRQ 8 output, not connected until the 8259s exist (M3). It
  starts from `tb/cmos_configured.hex` (assumption AT11).
- The runner accepts writes to empty expansion-slot addresses (AT10).
- An M1 defect is fixed: the board's "undriven read" flag fired during the
  wait states of a read whose device had not yet driven data; it is now
  checked when the read completes.

Result: with the 8042 and MC146818 on the board, the unchanged BIOS runs
1,125,813 instructions (1,084,662 with bus wait states), passes its CMOS
shutdown-byte test and its own 8042 test, and stops at `F000:068B`, a
write to port F1h at POST checkpoint 12h. Every instruction matches
Unicorn and the 8042 matches its reference model. See
[the M2 report](../report/2026-11-14-m2-8042-and-rtc.md).

## M3: coprocessor ports, interrupt controllers and shutdown (done)

Between `F000:068B` and the new stop the BIOS does the following, in order:

1. Writes port F1h, then initializes both 8259s (master ICW1 11h, ICW2 08h,
   ICW3 04h, ICW4 01h; slave ICW1 11h, ICW2 70h, ICW3 02h, ICW4 01h; then
   masks FFh).
2. Enters protected mode, runs POST checkpoints 13h–1Dh and sizes memory
   above 1 MB by writing AA55h to each 64K block and reading it back
   (routine HOW_BIG1, printed pages 5-46 and 5-47). It finds none.
3. Writes FEh to port 64h so that the 8042 pulses the CPU reset line, and
   halts until the reset arrives. This happens three times in the run.
4. Back in real mode, tests the 8259 mask registers, checks for unexpected
   interrupts, writes page registers 82h and 83h with one word
   `OUT 82h,AX` at `F000:0C9A` (checkpoint 27h), tests timer channel 2,
   unmasks IRQ 0 and takes four timer interrupts (vector 08h).
5. Runs further protected-mode tests (checkpoints F0h–FAh) and exercises
   the 8042 (keyboard disable and enable, test inputs, keyboard reset,
   interface test, command bytes, and D1h/DDh which closes the A20 gate).
6. Reads the MC146818 many times, writes video and diskette ports, then
   reads port 1F7h (fixed-disk status) at checkpoint 3Ch and stops there.

Done:

- Two 8259As on the board (sheet 16): master U114 and slave U125, selects
  from U123, -INTA from the 82288, IRQ 0 from the 8254, IRQ 1 from the
  8042, IRQ 8 from the MC146818, IRQ 13 from the coprocessor logic and
  IRQ 3–7, 9–12, 14–15 from the I/O channel (inactive). Assumptions
  AT13 and AT16.
- Math-coprocessor ports F0h and F1h (sheet 3). No 80287 is fitted
  (AT17).
- 80286 shutdown cycle to CPU reset through U84 and U105 (sheet 22),
  replacing the stand-in of assumption AT7. NMI stays unconnected: with no
  parity logic or I/O channel check modeled neither source can be active.
- I/O bus conversion: a word I/O cycle becomes two byte cycles for the
  8-bit board devices (AT15). Without it the BIOS failed checkpoint 27h.
- Runner: unpopulated memory (AT14); a halt ends the run only after
  2,000,000 processor clocks with interrupts disabled; a shutdown no
  longer ends the run; `A` and `Z` trace records; counters in the STOP
  line; an optional MC146818 log checked by `scripts/check_rtc_log.py`.
- The protected-mode memory test runs with no expansion memory fitted.
  Expansion RAM moves to a later milestone, tied to decision D1.

Result: with the new parts on the board, the unchanged BIOS runs
16,688,169 instructions (16,586,155 with bus wait states) and stops at
`F000:1453`, a read of port 1F7h at POST checkpoint 3Ch. Both scenarios
show 3 CPU resets and 8 interrupt-acknowledge cycles (4 interrupts,
vector 08h). The 8042 and the MC146818 match their reference models.
Every instruction state and data transfer of both runs matches Unicorn,
through protected mode, the interrupts, four exceptions and the resets. See
[the M3 report](../report/2026-11-15-m3-interrupts-and-protected-mode.md).

## M4a: I/O channel and EGA (done)

- `src/at_io_channel.sv`: 8-bit I/O channel cycles for memory
  A0000h–DFFFFh and unanswered I/O at 100h and above (AT18). The board
  gained the output `mem_cycle_o`, and an I/O read that no board device
  answers now takes its data from the host or channel instead of reading 0.
- `src/ibm_pc_at_5170_ega.sv`: the board, the channel and the IBM EGA
  (`design/ibm_ega`, 256 KB, IBM ROM 6277356 at C0000h), card IRQ2 on the
  board's IRQ 9, the clock arrangement of AT19, and card switches for the
  Enhanced Color Display in 350-line mode. CMOS image `tb/cmos_ega.hex`.
- Runner: `-DAT_EGA` build, frame rebuilt from the card's monitor
  connector, options `--stop-at`, `--stop-post`, `--max-cycles`, `--frame`
  and `--empty-slots`. `scripts/run_post_ega.sh` checks the stop point, the
  screen text, the 8042, the MC146818 and every instruction against
  Unicorn (system BIOS and EGA BIOS). The EGA machine is also synthesized.
- Finding: integration with the real EGA BIOS found an escaped defect in
  the card (attribute writes at 3C1 were not decoded), fixed in
  `design/ibm_ega` with a failure note, and showed that the EGA BIOS's sync
  test needs the clock arrangement of AT19.

Result: the BIOSes run 18,201,512 instructions and stop at `F000:1454`,
after the first read of port 1F7h, at POST checkpoint 3Ch. The EGA BIOS's
own self-test passes (256 KB found) and the last frame reads
`00640 KB OK`, ` 301-Keyboard Error`, ` 601-Diskette Error`. The bare
board's regression is unchanged. See
[the M4a report](../report/2026-11-16-m4a-io-channel-and-ega.md).

## M4b: VGA, keyboard input and diskette; full POST

Part 1 (VGA) is done; the keyboard device, the diskette adapter and the
full POST remain.

- VGA card (part 1, done): `src/ibm_pc_at_5170_vga.sv` puts `design/ibm_vga`
  (IBM PS/2 Display Adapter, 256 KB, DAC, adapter BIOS in the 32 KB window
  at C0000h) in the slot, card IRQ2 on IRQ 9, a colour analog monitor
  attached, and a card clock of twice the processor clock standing for
  48 MHz (an extension of AT19). The runner's `-DAT_VGA` build writes the
  DAC's 6-bit codes scaled to 8 bits per gun. `scripts/run_post_card.sh
  ega|vga` is now the one regression for either card (`run_post_ega.sh` and
  `run_post_vga.sh` are wrappers), and `scripts/check_frame.py` reads
  720 x 400 VGA text. Result: 16,294,929 instructions, the same stop at
  `F000:1454`, the same three screen lines, 8042, MC146818 and Unicorn all
  pass; the machine synthesizes to 129,054 generic cells. The EGA machine's
  results are unchanged. The bare-board regression was not rerun on this
  branch. See [the M4b part 1 report](../report/2026-11-16-m4b-vga.md).
  The VGA ROM is a legally fetched input; it could not be cross-checked
  against an IBM listing.
- Keyboard device on the 8042's keyboard connector, with scan codes from
  the host. Without it the BIOS reports error 301 and waits at
  `(RESUME = "F1" KEY)` (checkpoint 3Fh in the exploratory run).
- AT diskette adapter with the 8272 (error 601 today).
- The fixed disk at 1F0h–1F7h comes first in the BIOS's order; the
  regression's stop is the read of 1F7h. Either fit the controller (M5) or
  decide how far the regression should run past it.
- Goal: POST completes and the BIOS attempts to boot. Web panel and
  waveform screenshot in the README. Screen text compared with an
  independent machine (86Box or PCjs).

## M5: PC DOS

- Boot PC DOS from diskette, run DIR, write and read back a file.
- AT fixed-disk controller at 1F0h (new design), then boot from it.

## M6: OS/2 1.0 and CPGREP

- Settle decision D1 and memory size. Expansion RAM above 1 MB (moved here
  from M3) follows that decision.
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
