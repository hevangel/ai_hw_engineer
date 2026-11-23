# 8086/8088 PC compatibility — 2026-11-22

## Result

The VGA machine, with the unchanged AT REV1 BIOS and the repository's
80286, runs the IBM PC's own diskette software and shows what the 8088
machines show. Two workloads, each driven only through the keyboard (scan
code set 2 into the AT keyboard model and the 8042) and the simulator's run
slices, ran on the AT and, with the same keystrokes, on the repository's
8088 machines:

- **dos100** — the steps of `system/ibm_pc/scripts/test_software.py` on
  original PC DOS 1.00 (160 KB, single-sided) in the 1.2 MB drive A and the
  PC system's blank 160 KB data diskette in a 360 KB drive B: date entry,
  `DIR`, `CHKDSK`, `FORMAT B:` (insert prompt, all 40 tracks, decline
  another), `COPY TIME.COM B:CLOCK.COM`, `DIR B:`, `BASIC` with `PRINT 6*7`
  (`42`) and `SYSTEM`, and `BASICA DONKEY` (title screen, CGA graphics after
  the space bar, picture changes after another space bar). Reference: the
  IBM PC 5150 machine (`system/ibm_pc`).
- **dos200** — the diskette steps of `system/ibm_pc_xt_5160/scripts/test_software.py`
  on PC DOS 2.00 Disk 1 (180 KB) in drive A and Disk 2 in drive B: date and
  time, `DIR`, `ECHO AT 5170 8086 COMPAT>B:ECHO.TXT`, `TYPE` it, `COPY CON
  B:KEYED.TXT` (one line, Ctrl+Z, Enter), `TYPE` it, `BASIC` with
  `PRINT 6*7` and `SYSTEM`. Reference: the IBM PC XT 5160 machine
  (`system/ibm_pc_xt_5160`) booted from drive A (`IBM_XT_BOOT=A`).

Every text screen at the end of every step is identical on the two
machines, line for line, except for the expected differences below; the
drive B diskette DOS 1.00 formatted and wrote is byte-identical on the PC
and the AT, and the DOS 2.00 drive B images differ only in the files' time
stamps. No 80286 or board defect was found: nothing in the RTL changed.

| Check | Command | Result |
|---|---|---|
| AT, PC DOS 1.00 workload | `scripts/run_dos_8086.sh "$ROM"` | Pass: 16 steps; 36,719,857 instructions, 579,600,000 clocks (about 27 min wall, writing the trace); 3 CPU resets (POST), 2,024 interrupt acknowledges, 77,312 DMA writes and 8,544 DMA reads, no DMA outside RAM; drive B formatted and written (169,984 media bytes); DONKEY in BIOS mode 4 |
| PC 5150, same keystrokes | same | Pass: 18,418,962 instructions, 328,863,636 clocks |
| PC/AT comparison, DOS 1.00 | same (`scripts/compare_8086.py`) | Pass: 13 text screens identical (DONKEY's graphics screen is compared as a picture: both in a graphics mode, picture changes after the space bar); CHKDSK `40 disk files`, `160256 bytes total disk space`, `6144 bytes remain available` on both; `CLOCK.COM` on drive B equals `TIME.COM` of the DOS diskette (250 bytes) on both, read by the script's own FAT12 reader; the two 163,840-byte drive B images are identical |
| AT, PC DOS 2.00 workload | same | Pass: 11 steps; 21,070,788 instructions, 326,000,000 clocks; 3 CPU resets, 1,244 interrupt acknowledges, 91,648 DMA writes and 5,120 DMA reads |
| XT 5160, same keystrokes | same | Pass: 13,590,621 instructions, 228,000,000 clocks |
| XT/AT comparison, DOS 2.00 | same | Pass: 11 text screens identical after the time-of-day line; `ECHO.TXT` = `AT 5170 8086 COMPAT\r\n` and `KEYED.TXT` = `HELLO FROM COPY CON\r\n` on both; the 184,320-byte drive B images differ only in the two new directory entries' time fields (root directory sector 5 and the stale directory copy in the unused tail of the files' sectors 190 and 191) |
| 80286 against Unicorn, DOS 1.00 run | same (`check_post_trace.py --boot`) | Pass: all 36,719,857 instructions from power-on match (after extending the oracle; see "Unicorn replay") |
| 80286 against Unicorn, DOS 2.00 run | same | Pass: all 21,070,788 instructions match |
| 80286 design software regressions (oracle scripts changed) | `design/intel_80286/scripts/run_software.sh` | Pass: 17 checks (firmware trace to the ROM checksum, 196,846 states; hex-helper, IRQ8 timer and system-register cases; timer/DMA/page and native-bus BIOS replays) |
| 286-vs-8086 instruction differences | `scripts/scan_286_differences.py` on both traces | See "Genuine 286 differences" below |
| PC DOS 3.00 regression (simulator changes) | `scripts/run_dos_boot.sh "$ROM"` | Pass, unchanged: 460,000,000 clocks, 29,043,745 instructions, 5 CPU resets, `HELLO` read back (1,119 s wall) |
| Waveform capture invariant (simulator changes) | `scripts/test_capture.py` on the two-drive build | Pass: captures of 1,024, 4,096 and 65,536 clocks leave the state as an ordinary run |

The whole regression, `sh system/ibm_pc_at_5170/scripts/run_dos_8086.sh "$ROM"`,
was then run once more end to end with the final scripts and passed
(`PASS: the AT runs the 8088 PC's DOS 1.00 and 2.00 diskette workloads with
the same results`, 4,212 s wall), with the same instruction counts and both
Unicorn replays passing.

All runs were made on 2026-11-22 in the `ai-hw-engineer:latest` image
(Verilator 5.052) in container `claude-at-8086`, the four workload runs in
parallel on a 32-thread host. The instruction counts of the AT runs were the
same in an earlier exploratory run of the same build, so the runs are
deterministic.

## What was built

- **Drive B and single-sided media.** `tb/at_diskette_media.hpp` accepts
  the 5150's single-sided images, 160 KB (40 x 1 x 8) and 180 KB
  (40 x 1 x 9), recorded on side 0 only (ASSUMPTION AT38), in either drive
  type. The REV1 BIOS reads them as 320/360 KB media: at 300 kbit/s with
  double stepping in the 1.2 MB drive A, at 250 kbit/s in the 360 KB
  drive B. Drive B and the 360 KB drive type existed but had never run in a
  regression; FORMAT and COPY now exercise them.
- **CMOS for two drives.** `tb/cmos_vga_2fd.hex` (AT39): byte 10h = 21h
  (A high capacity, B 360 KB) and two drives in the equipment byte 14h, from
  the CMOS map of the IBM PC AT Technical Reference (printed pages 1-45 to
  1-52); checksum 00E4h. `scripts/build_host.sh` takes it with
  `AT_HOST_CMOS` (the image is built into the model, so each image gets its
  own `AT_HOST_OBJ`).
- **Simulator** (`host/simulator.cpp`): `SAVE unit path` writes a drive's
  image; `CODES` returns the screen as character codes (so the AT screen
  can be written exactly as the 8088 machines write their video memory);
  the screen reader also matches reverse-video cells (BASIC's function-key
  line); the state reports the BIOS video mode (0:0449h) and columns;
  `--trace=PATH` writes the processor trace of `tb/post_runner.cpp` (B, D,
  R, A, Z and G records) for the Unicorn replay, ending at an instruction
  boundary when the simulator quits (logged as `TRACE end=CS:IP`). The DMA
  memory transfer is now committed before the processor's bytes of the
  same clock, as in `post_runner.cpp`; the two cannot touch the same byte.
  The host wrapper exposes the trace taps (`retire_pc_o`,
  `retire_opcode_o`, `regs_o`, `segs_o`, `a20_gate_o`).
- **Workload driver** (`scripts/dos_8086_workload.py`): one definition of
  each workload and three machine back ends (AT, PC 5150, XT 5160) over
  their public line protocols. Each step types keys and waits until a
  screen condition holds; every step's final screen and the screens seen
  are saved in `result.json`, with drive B saved after the run.
- **Comparison** (`scripts/compare_8086.py`): screen-by-screen comparison
  with a list of expected differences (each must be explained, and is
  printed when used), CHKDSK numbers, and a FAT12 reader written for this
  check from the IBM DOS media-descriptor table (not from DOS or either
  simulator) that extracts the files DOS wrote on drive B.
- **Regression** (`scripts/run_dos_8086.sh BIOS [--no-reference]
  [--no-oracle]`): media (the PC and XT systems' pinned, hash-checked
  `prepare_images.py`), the two-drive AT build, the 8088 builds, the four
  runs in parallel, both comparisons and both Unicorn replays.

## Expected differences

| Difference | Where | Why |
|---|---|---|
| `bytes total memory` / `bytes free` in CHKDSK | dos100 | DOS 1.00 reports the memory the BIOS gave it: 64 KB on the PC 5150 model (65,536 / 53,392), 640 KB on the AT (655,360 / 643,216). The difference in free memory is exactly the difference in total memory |
| `Current time is` | dos200 | DOS 2.00 shows the BIOS time of day. The AT BIOS starts it from the MC146818 (12:00 in the CMOS image), the XT has no clock and counts from power-on (`0:00:30.15` against `12:00:29.10`). The date line is the same: DOS 2.00 does not read the RTC date |
| File times on drive B | dos200 | Follows from the time of day; only directory-entry bytes 22-23 differ |
| BIOS banner `00640 KB OK` | both (not reached) | The AT BIOS's memory count line; DOS clears or scrolls it away before the first compared screen, so no rule fired in these runs |
| Memory, speed, clock counts | both | Not compared: 64 KB / 256 KB / 640 KB machines, 4.77 MHz against the AT time base (AT19); the AT runs about 1.8 times as many instructions, nearly all in the BIOS's own wait loops |
| DONKEY's picture | dos100 | Compared as "graphics mode, at least 3 colours, changes after the space bar" on each machine: the PC model's screen is CGA memory, the AT's is the VGA's monitor signal; no pixel-level comparison was made |

## Genuine 286 differences

`scripts/scan_286_differences.py` counted, in both AT traces, the
instructions whose result differs between the 8086 and the 80286
(210498-005; PUSH SP pushing the old SP, shift counts masked to 5 bits,
opcodes the 8086 decodes differently or that raise #UD on the 286) and
instruction fetches above 1 MB.

- No PUSH SP, no shift or rotate by CL >= 32 and no 186/286-only or
  undefined opcode was executed by DOS, COMMAND, CHKDSK, FORMAT, COPY,
  BASIC, BASICA or DONKEY (the RAM and ROM BASIC regions). The only such
  opcodes were 0Fh, 60h-62h and C0h in the system BIOS's own POST (its
  protected-mode and processor tests), which the AT BIOS expects.
- **A20 wrap at 1 MB: hit.** BASICA under PC DOS 1.00 calls DOS through the
  CP/M-style entry at PSP:0005, which holds `CALL F01D:FEF0`; F01D0h +
  FEF0h = 1000C0h. On the 8086 the address wraps to 000C0h, where DOS keeps
  a far jump to its dispatcher. On the AT the 80286 forms 1000C0h, and the
  board's A20 gate (the 8042's output port, left off by the BIOS at the end
  of POST: the trace has exactly one A20 change) masks bit 20, so the fetch
  reads 000C0h. The DOS 1.00 run executes this 62 times while BASICA loads
  DONKEY.BAS. This is the genuine 286 difference the IBM AT's A20 gate
  exists for; the board implements it and the run agrees with the 8088
  PC. With A20 enabled the same program would fetch from 1000C0h (no
  memory there in this machine) and fail.
- Offset-FFFFh word accesses and #UD: the Unicorn replay compares every
  transfer and fault. Each run takes 4 exceptions, all in the system BIOS's
  POST tests (13 at F000:1CAC and F000:1E02, 5 at F000:1D3B and F000:1D5F);
  none in DOS or BASIC, so neither a word access at offset FFFFh nor an
  undefined opcode was hit.
- NT/IOPL in FLAGS: hit once, without effect (see "Unicorn replay").

## Unicorn replay

Every instruction of both AT runs, from power-on to the end of the
workload, is replayed against Unicorn 2.1.4 by `check_post_trace.py --boot`
with the system BIOS and the VGA BIOS, DMA (D) and A20 (G) records applied.
The first replay of the DOS 1.00 run stopped at physical 7C8Bh, the far
jump of the DOS 1.00 boot sector into IBMBIO (`2E FF 2E`, JMP FAR [mem]):
the oracle's decoder (`design/intel_80286/scripts/generate_firmware_trace.py`,
a whitelist of the forms the BIOS uses) did not accept it. This is an
oracle coverage gap, not a CPU disagreement. Before extending it, a scan of
both traces (applying their own memory writes and DMA records to a memory
image and decoding every retired instruction) listed every form it
rejected: DAA (27h, 9,088 times), the immediate group 82h (5,495), CALL FAR
direct (9Ah, 4,201), JMP FAR [mem] (FF /5, 872 including prefixes), XLAT
(D7h, 2) and the 62 wrapped fetches at 1000C0h. The decoder now accepts
DAA/DAS/AAA/AAS, 9Ah, FF /5 with a memory operand (the register form stays
undefined, 210498-005 Appendix B JMP), XLAT and 82h as 80h (the 286
design's assumption A34); `bios_replay.py` sets the flags these define and
leaves the ones 210498-005 Appendix B leaves undefined (DAA/DAS: OF;
AAA/AAS: OF, SF, ZF, PF) out of the comparison, and folds an instruction
fetch at 1 MB or above to the low address while the A20 gate is low, as it
already did for data transfers.

Two more oracle defects showed up in the next replays (failure note
[2026-11-22-intel80286-oracle-dos-coverage](../../../failure_notes/2026-11-22-intel80286-oracle-dos-coverage.md)):

- ROM BASIC at F600:26DC runs `OR` then `LAHF`. OR leaves AF undefined
  (210498-005 Appendix B); the RTL keeps the old AF (AH = 12h), Unicorn
  clears it (02h). The replay excluded AF from the flags comparison but
  compared LAHF's AH with a fixed mask. LAHF's AH is now compared only in
  the flags still defined, and the CPU's AH is adopted
  (`lahf_undefined_adopted`).
- PC DOS 2.00's IBMBIO at 0070:0A1D stores into its own code a few bytes
  ahead (`MOV CS:[0A2E],DL`). Unicorn 2.1.4 stepped with `count=1` abandons
  such an instruction to retranslate the page and returns with IP
  unchanged, every time (reproduced in a ten-line Unicorn script). The
  replay now runs a sequential instruction that Unicorn left in place again
  up to its next address, then compares its transfers as usual
  (`self_modifying_restarts`).

None of the three stops was a CPU disagreement, and no RTL changed. Results
with the extended oracle:

| Run | Result |
|---|---|
| PC DOS 2.00 | Pass (1,443 s wall): 21,070,788 instruction states and data transfers match up to `00DB:1683`, 0 trailing transfers; 13 of 13 POST checkpoints; 622 hardware interrupts (`08r` 136, `09r` 361, `0er` 125), 37,960 software interrupts, 4 exceptions (all in the BIOS's POST tests), 3 resets, 1 A20 change, 6 interrupted repeats, 91,648 DMA writes and 5,120 DMA reads, 5 self-modifying restarts, 2 ESC without a coprocessor |
| PC DOS 1.00 | Pass (2,464 s wall): 36,719,857 instruction states and data transfers match up to `F600:6BB0`, 0 trailing transfers; 13 of 13 POST checkpoints; 1,012 hardware interrupts (`08r` 497, `09r` 217, `0er` 298), 22,023 software interrupts, 4 exceptions (all in the BIOS's POST tests), 3 resets, 1 A20 change, 62 fetches folded at 1000C0h, 5 interrupted repeats, 77,312 DMA writes and 8,544 DMA reads, 70 LAHF results with an undefined AF adopted, 2 ESC without a coprocessor |

The replay also adopts the CPU's flags image where it differs only in
flags Unicorn cannot judge for a 286 (`flags_image_differences`): nearly
all are AF after logical instructions (undefined). One, at 0534:0180 in the
DOS 2.00 session (an INT n frame), differs in bits 12-14: the program had
loaded FLAGS with POPF or IRET, which on the 286 in real mode leave NT and IOPL
unchanged (210498-005 B-86; `design/intel_80286/spec/memory_execution.md`)
while Unicorn, modelling a later CPU, loads them. An 8086 would show bits
12-15 as ones there. This is a genuine 286/8086 difference executed by the
software; it changed nothing visible (the screens and files agree with the
XT).

## DOS 2.00 note

The first DOS 2.00 workload wrote to `B:CON.TXT`. DOS 2.00 treats a device
name with any extension as the device, so `COPY CON B:CON.TXT` copied the
keyboard to the screen and `TYPE B:CON.TXT` waited for keyboard input; both
the XT and the AT behaved the same way. The file is now `B:KEYED.TXT`.

## Limits

- DONKEY is compared by behaviour (graphics mode, colours, change after the
  space bar), not by pixels.
- The comparison covers final text screens of each step, not every
  intermediate frame, and keystroke timing is each machine's own (30 ms key
  spacing on the AT keyboard model, the 8088 hosts' own pacing).
- Single-sided media in a double-sided drive are modeled as unrecorded on
  side 1 (AT38); the workloads never select head 1 on them.
- 720 KB and 1.44 MB media are not supported by the REV1 BIOS and not
  modeled. The fixed disk is still not modeled.
- The AT's diskette and DMA timing are not the real board's (AT25, AT27).
