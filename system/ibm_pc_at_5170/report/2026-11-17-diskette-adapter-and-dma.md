# M4b: diskette adapter and DMA — 2026-11-17

## Result

The IBM PC AT's two 8237 DMA controllers now move data, and both display
machines have the diskette function of the IBM Fixed Disk and Diskette
Drive Adapter in a slot. The unchanged REV1 BIOS passes its diskette test
(no `601-Diskette Error`), and in the VGA machine, after F1 is pressed at
the 301 prompt, it boots a script-built 1.2 MB diskette at 500 kbit/s
through the controller and DMA channel 2. The boot program (our own code)
reads the whole 1.2 MB test file with INT 13h (79 cylinders, multi-sector
reads across the head boundary), checks its sum, writes a sector, reads it
back and prints `PASS`. Every 80286 instruction of the run matches Unicorn
with the DMA transfers applied as device inputs, and an independent model
of the adapter and the 765/8272 protocol agrees with every result byte,
status read, change-line read and DMA byte and with the written-back image.

| Check | Command | Result |
|---|---|---|
| Boot 1.2 MB diskette (640 KB) | `scripts/run_boot_diskette.sh "$ROM"` | Pass: `kind=halt at=0000:7EEC post=43`; 27,368,206 instructions, 417,466,520 clocks; 1,209,344 DMA writes, 512 DMA reads, 16 empty-80287 port accesses; 3,735 IDs, 196 IRQ 6s, 243 steps; 1,149 video frames; screen `AT DISKETTE BOOT TEST` / `READ OK` / `WRITE OK` / `PASS`; boot sector at `7C00h` and LBA 2399 write-back verified |
| Diskette/controller model (640 KB) | same (`check_fdc_log.py`) | Pass: 833 result bytes, 1,209,344 DMA bytes read, 512 written, 4,981 status reads, 84 digital input reads, 2 resets (83 reads, 5 recalibrate, 105 seek, 21 sense drive, 112 sense interrupt, 2 specify, 1 write); written-back image identical |
| 8042 and MC146818 (640 KB boot) | same | Pass: 14,417,787 8042 instructions (41,025 CPU reads, replies `55 FF 3B BB 02 FA AA`); 36,916 RTC strobes (36,889 reads, `12:00:28`) |
| 80286 Unicorn oracle (640 KB boot) | same (`check_post_trace.py`) | Pass (3,408 s wall): 27,368,206 instruction states and data transfers match up to `0000:7EEC`; `dma_writes=1209344`, `dma_reads=512`, `esc_without_coprocessor=2`, `interrupted_rep=1`, `hardware_interrupts=404` (`08r`: 207, `09r`: 1, `0er`: 196), 13 of 13 POST checkpoints |
| Boot 1.2 MB diskette (2 MB) | `scripts/run_boot_diskette.sh "$ROM" --ext-kb=1024` | Pass: `kind=halt at=0000:7EEC post=43`; 39,749,282 instructions, 591,466,611 clocks; 1,209,344 DMA writes, 512 DMA reads, `ext_kb=1024`, 16 empty-80287 port accesses; 1,645 video frames; screen, `7C00h` boot sector, LBA 2399 write-back and `check_fdc_log.py` identical |
| 8042 and MC146818 (2 MB boot) | same | Pass: 20,872,359 8042 instructions (41,026 CPU reads, replies `55 FF 3B BB 02 FA AA`); 5,083 RTC strobes (5,056 reads, `12:00:57`) |
| 80286 Unicorn oracle (2 MB boot) | same (`check_post_trace.py`) | Pass (4,740 s wall): 39,749,282 instruction states and data transfers match up to `0000:7EEC`; `accessed_writes=3091`, `dma_writes=1209344`, `dma_reads=512`, `esc_without_coprocessor=2`, `interrupted_rep=1`, `hardware_interrupts=402`, 13 of 13 POST checkpoints |
| D/G record self-tests | `scripts/test_board_records.py` | Pass: 8 of 8 on 640 KB trace and 10 of 10 on 2 MB trace (including `gate-clean` and `gate`) |
| VGA POST | `scripts/run_post_vga.sh "$ROM"` | Pass (2,797 s wall + oracle rerun): `kind=stop-at after=F1453 at=F000:1454 post=3C`; 16,610,979 instructions, 225,013,662 clocks; screen `00640 KB OK` / `301-Keyboard Error` (no `601`); 8042 (8,002,515), MC146818 (53,511) and Unicorn (13/13) pass |
| EGA POST | `scripts/run_post_ega.sh "$ROM"` | Pass (3,114 s wall + oracle rerun): `kind=stop-at after=F1453 at=F000:1454 post=3C`; 18,029,214 instructions, 273,013,658 clocks; screen `00640 KB OK` / `301-Keyboard Error` (no `601`); 8042 (9,787,012), MC146818 (31,922) and Unicorn (13/13) pass |
| Bare-board POST (two scenarios) | `scripts/run_post.sh "$ROM"` | Pass (4,710 s wall + oracle rerun): both stop at `F000:1453` (`1F7h`, POST `3C`); 16,688,169 and 16,586,155 instructions match Unicorn (13/13); 8042 (7,777,553 and 10,543,228) and MC146818 (22,855 and 14,538) pass |
| Synthesis | `scripts/run_synth.sh` | Pass (4,157 s wall): `ibm_pc_at_5170` 86,879 cells, `at_diskette_adapter` 6,920, `ibm_pc_at_5170_ega` 100,510, `ibm_pc_at_5170_vga` 136,117; `check -assert` clean; only the refresh arbiter latch |

All Verilator and Yosys runs were made on 2026-11-17 in the `ai-hw-engineer` image (Verilator 5.052) in container `claude-at-fdc`, several in parallel on a 32-thread host; the final `check_post_trace.py` runs (after extending `bios_replay.py` and `generate_firmware_trace.py` for mid-`REP` interrupts, `AAD`/`AAM`, and `ESC` decoding) ran in `claude-at-fdc` and the final `test_board_records.py` runs via `uv` (`unicorn==2.1.4`) on the Windows host.

## What was built

- **Board DMA** (`src/ibm_pc_at_5170.sv`, "DMA and pages"). Two
  `design/intel_8237` instances replace the 286 design's register-only
  fixture, wired from sheet 14 (U111 for channels 0-3, U122 for 4-7, U111's
  HRQ into U122's DREQ0, U122's -DACK4 inverted by U121 into U111's HLDA,
  U96 making T/C from both EOPs), sheet 21 (U122's HRQ into the existing
  refresh/DMA arbiter, whose DMA grant is U122's HLDA and which holds the
  80286 through HOLD/HLDA) and sheets 13/15 (the DACK lines select the
  74LS612 register: channel 2 uses 81h). The 24-bit DMA address is
  {page register, 8237 address}; it is driven ahead of the A20 gate, so the
  8042's gate never masks it. New board ports: `dma_drq_i[3:0]`,
  `dma_io_rdata_i[7:0]`, `dma_mem_o`, `dma_mem_write_o`, `dma_ior_n_o`,
  `dma_iow_n_o`, `aen_o`, `tc_o`, `dack_n_o[3:0]`; during a DMA transfer
  `address_o` and `data_o` carry the DMA address and byte, and the host
  serves the memory side exactly like a CPU byte access (`mem_rdata_i`).
- **Diskette adapter** (`src/at_diskette_adapter.sv`): DOR 3F2h, the 8272
  at 3F4h/3F5h, data rate (3F7h write), digital input with the change line
  (3F7h read), DRQ2/-DACK2/T/C, IRQ 6, RESET DRV, and the drive cable and
  decoded-media interface brought out. It also carries the idle task file
  1F1h-1F7h of the card's fixed-disk function (see "Findings").
- **System unit** (`src/at_system_unit.sv`): the board, the I/O channel and
  the adapter once, used by `ibm_pc_at_5170_ega` and `ibm_pc_at_5170_vga`
  (names and ports kept; DMA and `fd_*` drive ports added).
- **Drives and media** (`tb/at_diskette_media.hpp`, reusable by the web
  simulator): two drives (1.2 MB or 360 KB), raw images (1.2 MB, 360 KB,
  320 KB), IDs and data at the medium's data rate only, index pulses, step,
  track 0, change line, write protect, write and format back into the
  image (AT34).
- **Runner** (`tb/post_runner.cpp`): `--fda`, `--fdb`, `--fda-type`,
  `--fdb-type`, `--fda-ro`, `--fdb-ro`, `--write-back`, `--f1-at-post`,
  `--ext-kb`, `--progress`, TRACE `-` (no trace); D (DMA) and G (A20 gate)
  trace records; K records in the 8042 log; DMA, SPEED and DISKETTE summary
  lines; the empty 80287 socket's port accesses counted.
- **Test media** (`scripts/make_test_diskette.py`, `tb/boot_diskette.S`):
  blank and bootable FAT12 1.2 MB (and 360 KB) images; the boot program is
  assembled by GNU as as 80286 code.
- **Checks**: `scripts/run_boot_diskette.sh` (with `--ext-kb=1024` for the
  2 MB machine), `scripts/check_fdc_log.py` (independent adapter/765/drive
  model), `scripts/test_board_records.py` (D/G record self-tests),
  extensions of `scripts/check_kbc_log.py` (K records),
  `scripts/check_post_trace.py` (`--ext-kb`, `--boot`) and
  `design/intel_80286/scripts/bios_replay.py` (D and G records, expansion
  RAM, ESC without a coprocessor).
- **CMOS** `tb/cmos_vga_2mb.hex`: 640 KB base and 1024 KB expansion memory,
  checksum 00A7h.

## Findings

1. **The BIOS needs the fixed-disk task file to read a 1.2 MB diskette.**
   At checkpoint 3Ch the REV1 BIOS waits for 1F7h to clear busy and then
   writes and reads back 55h and AAh at 1F4h (F000:1453-147C); only then
   does it set HF_CNTRL "dual" (40:8Fh), which the diskette BIOS needs to
   choose the data rate per medium. With the adapter answering only the
   diskette ports (as first built, and as the brief proposed) the boot read
   ran at 250 kbit/s and failed with ST0 40h, ST1 05h (no ID) four times,
   and the BIOS went to INT 18h. The adapter now has the idle task file of
   a controller with no drive (AT37). The POST runs still stop after the
   same instruction, F000:1453; the value it reads is now 00h instead of
   the empty slot's FFh.
2. **The empty 80287 socket.** Once F1 is accepted the BIOS runs FNINIT at
   F000:15EF (checkpoint 40h); the 80286 writes the ESC opcode to port F8h,
   which the board did not decode. Sheet 1 wires the socket's PEREQ, PEACK,
   BUSY and ERROR straight to the 80286; BUSY and ERROR have pull-ups. The
   board now claims F8h-FFh with nothing behind it (AT17, AT36); the CPU
   moves no operand (no PEREQ), FNSTCW leaves the BIOS's word at 0000h, the
   BIOS finds no coprocessor (CMOS equipment bit 1 is 0, so no mismatch
   message), and the 2 MB run reports the same. The Unicorn replay judges
   ESC instructions the same way instead of running Unicorn's x87.
3. **The keyboard stimulus must acknowledge.** While waiting for F1 the
   BIOS's INT 16h sends Set LEDs (EDh) to the keyboard and, with no reply,
   consumed the F1 make code as the failed acknowledgement, so POST waited
   forever. The bench stimulus now acknowledges host commands (FAh) as a
   keyboard does.
4. **A test-program bug caught by the 80286.** GNU as first emitted a 386
   conditional jump (0F 83) in the boot program; the RTL raised invalid
   opcode on it, as a real 80286 does. The program is now assembled with
   `.arch i286`.

No defect was found in `design/intel_8237`, `design/intel_8272` or
`design/intel_80286`; no failure note was needed.

## The keyboard arrangement

No keyboard device is attached (another branch builds one). The BIOS
reports 301 and waits for F1 at checkpoint 3Fh. The runner's
`--f1-at-post=3F` arms a bench stimulus (`F1Stimulus` in
`tb/post_runner.cpp`) when port 80h first shows 3Fh: it sends F1's make
and break codes in scan code set 2 (05h, F0h 05h) with a device-driven
clock (40 µs half period on the 8042's 6 MHz base), 11-bit frames with
odd parity, waiting for the lines to be released and resending a frame the
host inhibits; it also clocks in host commands and answers FAh (FAh AAh to
FFh, EEh to EEh). Nothing in the BIOS or memory is patched; the 8042 runs
its own firmware, and its reference-model check includes the stimulus's
line changes (K records).

## Oracles

- **Unicorn replay.** D records: a DMA byte stored in (write = 1) or read
  from (write = 0) physical memory, written in time order among the CPU's
  bus records. Rule: it belongs to the instruction whose R record follows
  and is applied to the oracle's memory before that instruction runs
  (reads are compared with the oracle's memory); a trace where that
  instruction touched the same address before the D record, or where the
  address is not RAM, is rejected. G records: the 8042's A20 GATE changed;
  it applies from the following instruction (rejected if that instruction
  already made a memory transfer); with the gate closed an oracle access
  with bit 20 set is folded onto the low address. Expansion RAM is RAM.
  ESC instructions with no 80287: IP advances, only port F8h-FFh writes
  are accepted, counted as `esc_without_coprocessor` (`generate_firmware_trace.py`
  `decode(..., extended=True)` also accepts `D4 0A`/`D5 0A` (`AAM`/`AAD`,
  with `OF`/`AF`/`CF` cleared from `valid_flags` in `bios_replay.py`) and
  `D8`-`DF` for `no_coprocessor=True`). Hardware interrupts taken between
  elements of a repeated string instruction (`REP STOSW` at `C000:07F0` in the
  640 KB boot run and `REP MOVSB` at `C000:0EBA` in the 2 MB boot run) replay
  the completed elements in Unicorn before vectoring (`interrupted_rep=1`).
  `scripts/test_board_records.py` replays cuts of the boot trace with one
  record corrupted: 8 of 8 cases pass on the 640 KB trace and 10 of 10 on the
  2 MB trace (`boot-clean`, `order-clean`, `dma-read-clean` and `gate-clean`
  pass; `boot-byte` and `boot-dropped` rejected at `0f1ba8`, `dma-outside` at
  step `12357878`/`24739025`, `order` at step `12536361`/`24917500`,
  `dma-read` at step `27300552`/`39681628`, and `gate` at `0f08f5` where the
  oracle folds `100000h` to `000000h`).
- **Diskette model** (`scripts/check_fdc_log.py`), written from the
  Technical Reference adapter section and the 8272A data sheet: commands,
  results, the SIS event queue after reset and seeks, MT head switching and
  the TC-ended result IDs (Intel Table 8), data rate against medium, the
  change line, track 0, DMA byte values and address continuity, and the
  final image. Not checked: timing.
- The 286 design's fixture regressions with the new `bios_replay.py`:
  `run_at_bios_native.sh` (247,306 and 247,355 instructions) and
  `run_at_timer_bios.sh` (247,196 and 1,295,769) pass, and their traces
  replayed with the previous `bios_replay.py` (commit 98fdf40) give the
  identical output lines.

## Simulation speed

- VGA machine, no trace (`work/try_vga/run0.log`, `run2.log`): `356,257`
  processor clocks/s to checkpoint `3Ch` (`225,013,662` clocks in `631.6 s`)
  and `344,112` clocks/s to checkpoint `40h` (`204,991,238` clocks in
  `595.7 s`).
- VGA machine with trace: `284,150` clocks/s alone (`417,466,520` clocks in
  `1,469.2 s`, `work/try_vga/run6.log`); `206,428` clocks/s (`2,022.3 s`)
  and `225,173` clocks/s (`2,626.7 s`) when running 640 KB and 2 MB boot
  simulations in parallel (`work/boot/run.log`, `work/boot_2mb/run.log`).
- POST regressions with trace in parallel: `267,122` clocks/s (`post_vga`),
  `287,876` clocks/s (`post_ega`), `334,555` and `276,067` clocks/s (`post`
  wait0 and wait1).

## Assumptions

New ledger entries AT25-AT37 (AT20-AT24 are reserved for the keyboard and
web branch), in [the specification](../spec/spec.md): AT25 DMA clocking and
no DMA wait states; AT26 only controller 1 moves data; AT27 the diskette
time base (6 MHz processor-clock base, four times fast against video) and
8 MHz controller timers at all rates; AT28 SA0-SA9 decode; AT29 data rate
reset; AT30 drive select with motor; AT31 READY always active, selected
drive's lines to every unit; AT32 DRQ2/IRQ 6 gating and TC with -DACK2;
AT33 digital input bits; AT34 the drives and media; AT35 expansion RAM;
AT36 the empty 80287 socket; AT37 the idle fixed-disk task file. AT4 is
retired and AT17 extended.

## Limits

- DMA and controller timing are not the board's (AT25, AT27); the adapter's
  logic diagrams (PDF 635-642) were not traced at a readable resolution
  (AT28-AT33 rest on the prose and the BIOS).
- No fixed disk; no 16-bit DMA; DMA into I/O-channel memory is not routed.
- Only drive A, a 1.2 MB drive with a 1.2 MB medium, is exercised by a
  regression; 360 KB media and drives, format, write protect and drive B
  are implemented but not regressed.
- The F1 stimulus is not a keyboard; the keyboard device is another
  branch's work.
- One scenario (no added wait states) for each machine.
- No comparison with an independent whole-machine emulator.
- The 2 MB (`--ext-kb=1024`) machine: completes POST with `tb/cmos_vga_2mb.hex`
  and passes the full 1.2 MB boot-diskette read/write/verify regression
  (`39,749,282` instructions, Unicorn pass).

## Reproduce

```sh
ROM=$(sh system/ibm_pc_at_5170/scripts/get_bios.sh)
sh system/ibm_pc_at_5170/scripts/run_boot_diskette.sh "$ROM"
sh system/ibm_pc_at_5170/scripts/run_boot_diskette.sh "$ROM" --ext-kb=1024
sh system/ibm_pc_at_5170/scripts/run_post_vga.sh "$ROM"
sh system/ibm_pc_at_5170/scripts/run_post_ega.sh "$ROM"
sh system/ibm_pc_at_5170/scripts/run_all.sh "$ROM"
```
