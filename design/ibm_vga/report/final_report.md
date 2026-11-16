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

Run of 2026-11-16 in container `claude-ibm-vga` (image `ai-hw-engineer:latest`
plus unicorn 2.1.4 and capstone): **PASS: ibm_vga complete flow in 1281 s**.

| Stage | Result | Time |
|---|---|---|
| Lint | `verilator --lint-only -Wall` clean on `ibm_vga` and each of the 10 sub-modules alone | 2 s |
| Formal | 4 targets proved (abc pdr) and covered (yices); 5 planted faults detected | 96 s |
| ROM | 86Box file hashes, MAME `ibm-vga.bin` CRC32/SHA-1 equal after the 8 KB rotation, header, checksum, sign-on, table | in simulation |
| Directed | 29 tests: the model meets every literal expectation, the RTL trace is identical | in simulation |
| Random | 32 seeds x 600 operations identical (45,113 trace lines, 1,628,148 dots, final register/DAC/256 KB dumps) | in simulation |
| BIOS geometry | 28 entries equal their registers; 22 display entries equal Figure 2-4/2-5 resolutions and HITR Figures 99-104 (40-column horizontal disagreement reported) | in simulation |
| Static I/O audit | 31 ports reachable, each decoded or documented as another device's; 52 sites resolved only by execution | in simulation |
| ROM execution | 5 Unicorn scenarios: POST passes (colour, mono, none); RTL = model on every replayed trace; mode 3, 12h, 13h pictures pixel-exact against images rebuilt from the ROM | in simulation |
| Clock ratio | 72 runs identical with clk at 29.0 and 47.3 MHz and irregular enables | in simulation |
| Coverage gate | 64 registers, 824 register bit values, 190 further items, all 28 BIOS entries and 5 executions: no hole | in simulation |
| Simulation total | | 741 s |
| Mutation | 20 of 20 mutants killed | 87 s |
| Synthesis | Yosys `synth -flatten`, `check -assert` clean, no latches | 355 s |

## BIOS mode-table geometry

Every non-empty VIDEO_PARMS entry (28 of 29) programmed as the BIOS's
SET_REGS does, measured on the RTL dot stream (identical to the model's).
The 22 display entries are also checked against VGAXGA Figures 2-4/2-5 and
HITR Figures 99-104 (timing set #1: 31.778 us lines, 3.813 us horizontal
sync, 0.064 ms vertical sync, 14.268/16.683 ms frames, vertical blanking and
porches per size, horizontal blanking and porches with/without border).

| Entry | Mode | Dot clock MHz | Chars x dots = dots/line | Lines/frame | HSYNC dots | Displayed | Line us | Frame ms | Line kHz | Frame Hz | VBlank / VFP / VBP lines | HBlank / HFP / HBP us | VSYNC/HSYNC polarity, border |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 00 | 0 | 25.175 /2 | 50 x 8 = 400 | 449 | 56 | 320x400 | 31.778 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.084 / 0.000 / 0.636 | +-, no border |
| 01 | 1 | 25.175 /2 | 50 x 8 = 400 | 449 | 56 | 320x400 | 31.778 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.084 / 0.000 / 0.636 | +-, no border |
| 02 | 2 | 25.175 | 100 x 8 = 800 | 449 | 96 | 640x400 | 31.778 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.720 / 0.318 / 1.589 | +-, border |
| 03 | 3 | 25.175 | 100 x 8 = 800 | 449 | 96 | 640x400 | 31.778 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.720 / 0.318 / 1.589 | +-, border |
| 04 | 4 | 25.175 /2 | 50 x 8 = 400 | 449 | 56 | 320x400 | 31.778 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.084 / 0.000 / 0.636 | +-, no border |
| 05 | 5 | 25.175 /2 | 50 x 8 = 400 | 449 | 56 | 320x400 | 31.778 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.084 / 0.000 / 0.636 | +-, no border |
| 06 | 6 | 25.175 | 100 x 8 = 800 | 449 | 96 | 640x400 | 31.778 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.720 / 0.318 / 1.589 | +-, border |
| 07 | 7 | 28.322 | 100 x 9 = 900 | 449 | 108 | 720x350 | 31.777 | 14.268 | 31.47 | 70.09 | 87 / 32 / 53 | 5.720 / 0.318 / 1.589 | -+, border |
| 08 | (8) | 25.175 | 100 x 8 = 800 | 449 | 96 | 640x400 | 31.778 | 14.268 | 31.47 | 70.09 | - | - | not a mode of this 256 KB card: registers only |
| 0A | (A) | 25.175 | 60 x 9 = 540 | 262 | 36 | 360x200 | 21.450 | 5.620 | 46.62 | 177.94 | - | - | not a mode of this 256 KB card: registers only |
| 0B | (B) | 25.175 /2 | 100 x 8 = 800 | 449 | 96 | 640x400 | 63.555 | 28.536 | 15.73 | 35.04 | - | - | not a mode of this 256 KB card: registers only |
| 0C | (C) | 25.175 /2 | 100 x 8 = 800 | 449 | 96 | 640x400 | 63.555 | 28.536 | 15.73 | 35.04 | - | - | not a mode of this 256 KB card: registers only |
| 0D | D | 25.175 /2 | 50 x 8 = 400 | 449 | 56 | 320x400 | 31.778 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.084 / 0.000 / 0.636 | +-, no border |
| 0E | E | 25.175 | 100 x 8 = 800 | 449 | 96 | 640x400 | 31.778 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.720 / 0.318 / 1.589 | +-, border |
| 0F | F (64K) | 25.175 | 101 x 8 = 808 | 370 | 128 | 640x350 | 32.095 | 11.875 | 31.16 | 84.21 | - | - | not a mode of this 256 KB card: registers only |
| 10 | 10 (64K) | 28.322 | 96 x 8 = 768 | 366 | 80 | 640x350 | 27.117 | 9.925 | 36.88 | 100.76 | - | - | not a mode of this 256 KB card: registers only |
| 11 | F | 25.175 | 100 x 8 = 800 | 449 | 96 | 640x350 | 31.778 | 14.268 | 31.47 | 70.09 | 87 / 32 / 53 | 5.720 / 0.318 / 1.589 | -+, border |
| 12 | 10 | 25.175 | 100 x 8 = 800 | 449 | 96 | 640x350 | 31.778 | 14.268 | 31.47 | 70.09 | 87 / 32 / 53 | 5.720 / 0.318 / 1.589 | -+, border |
| 13 | 0* | 25.175 /2 | 50 x 8 = 400 | 449 | 56 | 320x350 | 31.778 | 14.268 | 31.47 | 70.09 | 87 / 32 / 53 | 5.084 / 0.000 / 0.636 | -+, no border |
| 14 | 1* | 25.175 /2 | 50 x 8 = 400 | 449 | 56 | 320x350 | 31.778 | 14.268 | 31.47 | 70.09 | 87 / 32 / 53 | 5.084 / 0.000 / 0.636 | -+, no border |
| 15 | 2* | 25.175 | 100 x 8 = 800 | 449 | 96 | 640x350 | 31.778 | 14.268 | 31.47 | 70.09 | 87 / 32 / 53 | 5.720 / 0.318 / 1.589 | -+, border |
| 16 | 3* | 25.175 | 100 x 8 = 800 | 449 | 96 | 640x350 | 31.778 | 14.268 | 31.47 | 70.09 | 87 / 32 / 53 | 5.720 / 0.318 / 1.589 | -+, border |
| 17 | 0+/1+ | 28.322 /2 | 50 x 9 = 450 | 449 | 63 | 360x400 | 31.777 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.084 / 0.000 / 0.636 | +-, no border |
| 18 | 2+/3+ | 28.322 | 100 x 9 = 900 | 449 | 108 | 720x400 | 31.777 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.720 / 0.318 / 1.589 | +-, border |
| 19 | 7+ | 28.322 | 100 x 9 = 900 | 449 | 108 | 720x400 | 31.777 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.720 / 0.318 / 1.589 | +-, border |
| 1A | 11 | 25.175 | 100 x 8 = 800 | 525 | 96 | 640x480 | 31.778 | 16.683 | 31.47 | 59.94 | 29 / 3 / 24 | 5.720 / 0.318 / 1.589 | --, border |
| 1B | 12 | 25.175 | 100 x 8 = 800 | 525 | 96 | 640x480 | 31.778 | 16.683 | 31.47 | 59.94 | 29 / 3 / 24 | 5.720 / 0.318 / 1.589 | --, border |
| 1C | 13 | 25.175 | 100 x 8 = 800 | 449 | 96 | 640x400 | 31.778 | 14.268 | 31.47 | 70.09 | 35 / 6 / 27 | 5.720 / 0.318 / 1.589 | +-, border |

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

| Port | Dir | Card |
|---|---|---|
| 0040 | in/out | not the card: PIT counter 0 (system board), frame-time measurement in POST |
| 0042 | out | not the card: PIT counter 2 (system board), speaker tone for error beeps |
| 0043 | out | not the card: PIT mode register (system board) |
| 0061 | in/out | not the card: system port B (speaker gate) for error beeps |
| 0102 | out | decoded: pos |
| 0103 | out | not the card: high byte of the word OUT 102h,AX (C000:00A3): POS register 3, which HITR p.10 says the video subsystem does not use |
| 03B4 | out | decoded: crtca |
| 03B5 | in/out | decoded: crtcd |
| 03B8 | out | not the card: MDA mode control: POST test of a second (monochrome) adapter |
| 03BA | in/out | decoded: xa |
| 03C0 | in/out | decoded: attr |
| 03C1 | in | decoded: attr_data |
| 03C2 | in/out | decoded: c2 |
| 03C4 | in/out | decoded: seqa |
| 03C5 | in/out | decoded: seqd |
| 03C6 | in/out | decoded: pelmask |
| 03C7 | in/out | decoded: dac_ra |
| 03C8 | in/out | decoded: dac_wa |
| 03C9 | in/out | decoded: dac_data |
| 03CA | in | decoded: fcr_rd |
| 03CC | in | decoded: misc_rd |
| 03CE | in/out | decoded: gca |
| 03CF | in/out | decoded: gcd |
| 03D4 | in/out | decoded: crtca |
| 03D5 | in/out | decoded: crtcd |
| 03D8 | out | not the card: CGA mode control: POST test of a second (colour) adapter |
| 03DA | in/out | decoded: xa |
| 46E8 | out | decoded: vse |
| 46E9 | out | not the card: high byte of the word OUT 46E8h,AX (C000:009C/00AA): a second byte cycle, not decoded by the 8-bit card (the enable register is 46E8h alone) |
| 4AE8 | out | not the card: 8514/A Advanced Function Control (another IBM adapter): the POST writes 0 so an 8514/A passes VGA video through (C000:00AB-00B0) |
| 4AE9 | out | not the card: high byte of the word OUT 4AE8h,AX (8514/A register, another adapter) |

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

| Scenario | Load | POST result (BIOS data area) | Bus lines replayed | Ports used | Picture |
|---|---|---|---|---|---|
| exec_post_color | colour (111b) | no error beep; 40:87h=60h, 40:88h=09h, 40:89h=11h, equipment 0020h (80x25 colour), mode 03h | 1.23 M | 22 | mode 3 (9x16) text screen 720 x 400 equals the rebuilt image |
| exec_post_mono | mono (010b) | no error beep; 40:87h=62h, 40:88h=0Bh, 40:89h=17h, equipment 0030h (monochrome), mode 07h | 1.27 M | 23 | not checked |
| exec_post_none | none (000b) | no error beep; same BIOS data area as mono (the BIOS's no-display path ends in the monochrome set-up) | 1.27 M | 23 | not checked |
| exec_mode12 | colour | as colour, then INT 10h AX=0012h | 1.54 M | 22 | 640 x 480, 16 bands, equals the rebuilt image |
| exec_mode13 | colour | as colour, then INT 10h AX=0013h | 1.45 M | 22 | 640 x 400 dots (320 x 200 PELs), 256-colour ramp, equals the rebuilt image |

Every read value the model returned to the executing BIOS was met again by the
full-detail model in the replay, and the RTL trace equals the model's for all
five scripts. The ports actually used (102h, 103h, 3B4h/3B5h/3BAh, 3C0h,
3C2h, 3C4h/3C5h, 3C6h-3C9h, 3CCh, 3CEh/3CFh, 3D4h/3D5h/3DAh, 46E8h/46E9h,
4AE8h/4AE9h) are a subset of the static audit's list.

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

| Mutant | Fault | Killed by (first differing trace) |
|---|---|---|
| m1_fn_and_is_or | write path: function AND acts as OR | `random/r4` |
| m2_wm3_mask | write mode 3: rotated data not ANDed into the mask | `directed/write_modes` |
| m3_compare_inverted | read mode 1: Don't Care sense inverted | `directed/read_modes` |
| m4_c256_order | 256-colour serializer: low nibble first | `directed/mode13_pixels` |
| m5_chain4_paddr | chain 4: plane address keeps A1-A0 | `directed/odd_even_and_chain4` |
| m6_htotal | CRTC: HT+4 characters per line | `directed/tiny_frame_timing` |
| m7_protect | CRTC: Protect bit ignored | `directed/crtc_protect` |
| m8_double_scan | CRTC: double scan ignored | `directed/double_scan` |
| m9_vbe_bits | CRTC: vertical blank end compared on 5 bits | `random/r2` |
| m10_dword | CRTC: doubleword address without MA13-12 in bits 1-0 | `directed/doubleword_high_address` |
| m11_pel_width | attribute: PEL width pairs swapped | `directed/mode13_pixels` |
| m12_io_a10 | I/O decode: A10 decoded (no 400h aliases) | `directed/io_decode_aliases` |
| m13_enable_pos | card enable ignores POS 102h | `directed/card_enable` |
| m14_dac_order | DAC: read returns green first | `directed/dac_state_machine` |
| m15_pelmask | DAC: PEL mask not applied | `directed/dac_pel_mask` |
| m16_colsel | attribute: Color Select bits 3-2 not used for P7-P6 | `directed/color_plane_enable_and_select` |
| m17_text_depth | pipeline: alphanumeric depth equal to graphics (V14) | `directed/text_glyphs` |
| m18_sense | switch sense: open outputs not doubled | `directed/switch_sense` |
| m19_status_mux | Input Status 1 bits 5-4 always 0 (the V16 defect) | `directed/video_status_mux` |
| m20_attr_3c1 | I/O decode: 3C1 also accepts attribute writes | `directed/registers_readback` |

20 of 20 killed; each kill is a behavioural difference (RTL trace differs from the model), not a build or tool error. Mutants run the directed tests and 4 random seeds (the BIOS and clock-ratio stages are skipped inside mutants). m10 survived the first run: the tiny geometry never reached memory addresses of 4096 and above, where the doubleword output bits 1-0 carry MA13-12; test `doubleword_high_address` was added.

## Formal

| Target | Task | Result | Time |
|---|---|---|---|
| `vga_dac` | prove (abc pdr) / cover (yices) | PASS / 3 covers reached | 1 s |
| `vga_graphics_ctrl` | prove / cover | PASS / all covers reached | 2 s |
| `vga_crtc` | prove_h, prove_v / cover | PASS / 3 covers reached | 27 s |
| `ibm_vga` (RAM, ROM black boxes, DAC shadow entry) | prove / cover | PASS / all covers reached | 51 s |

Planted faults, each of which must make its proof fail: DAC sub-index wrap
at 3 (`vga_dac`), write mode 3 mask without the rotated data
(`vga_graphics_ctrl`), horizontal retrace end on 4 bits (`vga_crtc`
prove_h), vertical retrace end on 5 bits (`vga_crtc` prove_v), DAC decoded
in setup mode (`ibm_vga`): all 5 detected. The card-top script maps
memories and cells and turns the x bits of out-of-range selects behind
unreachable conditions into free values (`setundef -anyseq`) before the
proof, which can only make the proof harder.

## Synthesis

Yosys generic synthesis of `ibm_vga` with the four plane RAMs and the ROM
as black boxes: 40,826 cells, about 5,580 flip-flops (most of them the
256 x 18-bit DAC palette, 4,608 bits, kept in logic so the design stays
self-contained; an FPGA build would map it, like the planes, to block RAM).
`check -assert` is clean and no latch is inferred.

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
