# IBM PS/2 Display Adapter (ISA VGA): verification report

Design: `design/ibm_vga` (branch `design/ibm-vga`). Issues:
[#274](https://github.com/hevangel/ai_hw_engineer/issues/274) (VGA chip set),
[#275](https://github.com/hevangel/ai_hw_engineer/issues/275) (ISA card).
Contract: [spec/spec.md](../spec/spec.md) (assumption ledger V1-V25).

## How to reproduce

In the `ai-hw-engineer:latest` image (Verilator 5.052, Yosys, SBY with abc
pdr and yices, Python 3.14) plus `pip install unicorn==2.1.4 capstone`
(Unicorn is **not** in the image; it was installed into the run container):

```sh
sh design/ibm_vga/scripts/run_all.sh        # lint, formal, sim, mutation, synthesis
```

`run_all.sh` deletes the previous results, keeps `work/refs` and
`work/firmware`, downloads the ROM if missing and exits nonzero on the first
failure. Individual stages: `run_lint.sh`, `run_formal.sh`, `run_sim.sh
[SEEDS] [OPS]`, `run_mutation.sh`, `run_synth.sh`.

## Results (run_all.sh, clean work directory)

RESULTS_TABLE

## BIOS mode-table geometry

Every non-empty VIDEO_PARMS entry (28 of 29) programmed as the BIOS's
SET_REGS does, measured on the RTL dot stream (identical to the model's).
The 22 display entries are also checked against VGAXGA Figures 2-4/2-5 and
HITR Figures 99-104 (timing set #1: 31.778 us lines, 3.813 us horizontal
sync, 0.064 ms vertical sync, 14.268/16.683 ms frames, vertical blanking and
porches per size, horizontal blanking and porches with/without border).

GEOMETRY_TABLE

The horizontal pipeline depths (V14) were chosen from entries 18h (mode
3+) and 1Bh (mode 12h); the other 20 display entries are checks. For the
eight no-border 40-column entries (0, 1, 4, 5, D, 0*, 1*, 0+) IBM's
register values cannot produce HITR Figure 104 (see "Disagreements"); the
horizontal sync width and porches of those are reported, not gated. All
vertical figures and line/frame periods are gated for every display entry.

## Real software: the adapter BIOS

### Static I/O audit (lesson of failure_notes/2026-11-16-ibm-ega-attribute-3c1.md)

`scripts/rom_io_audit.py` disassembles the ROM recursively from its entry
points (0003h init, the INT 10h/6Dh handler 06E4h and its five jump tables,
the INT 10h vector, the save-pointer table) with a DX/BL/BH value tracker,
resolves DX-parameter helpers at all their call sites (nine helpers, for
example 1201h "OUT DX,AX with index AL, data from the table" with 9
callers, 2B30h with 16) and lists every reachable port:

AUDIT_TABLE

Every port is decoded by the card or is a system-board port (PIT 40h/42h/
43h, port 61h), another adapter's port the POST deliberately probes (MDA
3B8h, CGA 3D8h, 8514/A 4AE8h/4AE9h), or the high byte of a word OUT to an
8-bit card (46E9h, 103h; POS register 3, which HITR p.10 says is not used).
The values 0102h and 0103h are also loaded into DX as beep counts for the
error routine C000:0590 (not ports). **The ROM never writes 3C1h and never
accesses 3C3h**: it enables the adapter with 46E8h/POS 102h (V4, V5, V6).
Sites whose DX the tracker cannot resolve statically (DX from a caller's
register save, the CRTC base in DI) are covered by the execution below,
which sees every port actually used.

### Execution in Unicorn

`scripts/rom_exec.py` runs the ROM's own code (Unicorn 2.1.4, x86 real
mode) with the model as the card, in a minimal PC (RAM, IRET-stub
vectors, PIT channel 0, speaker port). The POST and INT 10h calls run
unmodified; each I/O cycle at port 100h and above and each memory cycle at
A0000h-BFFFFh goes through the slot as byte cycles and is recorded with
the value returned and the elapsed time (0.25 us per basic block, 1 us per
I/O, 0.5 us per card memory cycle). The recorded scripts (1.2-1.5 million
bus lines each) are then replayed on the full model (every read value is an
expectation) and on the RTL (trace equal to the model's).

EXEC_TABLE

The POST measures the frame time with the PIT (two frames, 400 lines,
C000:01E5-0259), tests 64 KB of video memory, the DAC (all 768 bytes
written and read back with 1Ah and 25h), the ISR1 video status bits for
three multiplexer settings, and senses the display with the five-value DAC
tables; with a colour load it selects mode 3 (9x16, 400 lines) and with a
monochrome load mode 7. Pictures (in `work/img/`, PPM and PNG): the POST's
own mode 3 with a text screen (720 x 400), INT 10h mode 12h with 16 colour
bands (640 x 480), INT 10h mode 13h with a 256-colour ramp (640 x 400 dots
= 320 x 200 PELs doubled) -- each equals, pixel for pixel, an image
rebuilt independently of the model from the ROM's 8x16 font and 9x16 patch
table, the ROM's VIDEO_PARMS attribute registers and the DAC values the
BIOS itself wrote (parsed from the bus script with the p.2-105 protocol).

### A defect found by the firmware stage

The first Unicorn POST beeped one long and three short (C000:02AB). The
POST loop at C000:0270-029B sets Color Plane Enable bits 5-4 to 00, 01, 10
and waits for Input Status 1 bits 5-4 to become nonzero and then zero.
HITR and VGAXGA mark those bits reserved, so the spec (old V16), the model
and the RTL all read them as 0; lockstep could not disagree and the
directed tests had asserted the documented reading. Fix: the EGA's video
status multiplexer (EGA TR p.17/p.60, EGA E11) on bits 5-4, tapping the
attribute controller output (0 in blanking); a second POST run showed the
tap must ignore Screen Off, because that loop runs with Clocking Mode 29h.
New: spec V16, directed test `video_status_mux` with literal values,
coverage `diag_nonzero_0..2`, mutant m19 (the old behaviour) must be
killed. The defect was caught by this design's own suite before any commit
of the stage, so no failure note was written; it is the reason the
firmware execution stage is mandatory in `run_all.sh`.

## Clock-enable requirement

`clk` must be at least as fast as the fastest oscillator enable driven:
28.322 MHz (clk / dot clock >= 1.0); then any enable pattern works.
`run_sim.sh` reruns all directed tests, two random seeds, entries 07, 18,
1B, 1C and the Unicorn mode 13h run with clk at 29.0 and 47.3 MHz and
phase-accumulator enables (`VGA_CLK_MHZ`): all traces equal the model's.
A host whose clock stands for 24 MHz (the AT machine top) must clock the
card faster than 28.322 MHz (for example at twice its rate).

## Mutation testing

MUTATION_TABLE

## Formal

FORMAL_TABLE

## Synthesis

SYNTH_TABLE

## Disagreements between documents, emulators and the ROM

| Item | Documents | ROM / emulators | Resolution |
|---|---|---|---|
| Enable port | HITR: planar 3C3h bit 0 and POS via 94h | ROM: 46E8h + 102h only; 86Box: 46E8h bit 3 AND 102h bit 0 | ROM (V4, V5) |
| Input Status 1 bits 5-4 | reserved (HITR, VGAXGA) | POST requires the EGA video status mux | ROM (V16) |
| PEL mask | HITR R/W; VGAXGA "R", "do not write" | BIOS writes 00h/FFh | R/W, ANDed (V19) |
| Switch sense | "test circuitry" only | five-value tables per display; 86Box: entry-0 threshold 26h, colour only | load comparator (V21) |
| 40-column horizontal timing | HITR Fig. 104: blank 6.356 us, sync 3.813 us | BIOS registers: blank 8 chars (5.084 us), End Retrace 00h after start 2Bh (21-char width by p.2-60, ended by the line wrap after 7 chars, 4.449 us) | registers; reported |
| ROM image | - | MAME 32 KB ROM-first BAD_DUMP; 86Box 8 KB zeros first, mapped from offset 2000h | same bytes; V22 |
| 3C1 writes | read-only | never written by the ROM; 86Box accepts them | not decoded (V6) |
| Chain 4 low address bits | not stated | 86Box `o & FFFCh` with its own display mapping | V15 from Figure 2-65 |

## Not modeled / limits

- Auxiliary video (feature) connector, monitor ID pins, 8514/A pass-through.
- Wait states, memory arbitration, DRAM refresh, the five-refresh-cycle bit,
  Shift 4 multiple-shift modes beyond storing the bit, byte panning beyond
  the start-address offset (V11).
- The DAC's 3-clock pipeline and analog output levels (V23); the sense
  comparator uses a reference inside the interval the ROM tables bound.
- The ROM's code and font fetches in the Unicorn run come from mapped memory,
  not through the card's ROM decode (covered by directed tests and formal).
- Unicorn time is virtual (per block / per access); real 286 timing would
  shift the bus script but not the checks.
- The monochrome and no-display POST runs check the BIOS outcome, not a
  picture.
- The Unicorn and capstone Python packages are not part of the
  `ai-hw-engineer` image.
