# IBM EGA verification report: 2026-11-16

## Result

The RTL (`src/`, one module per device) matches the reference model
`scripts/ega_model.py` on every trace line of every test. The model was
written from IBM's technical reference (TR, August 2, 1984) and the spec
contract before the RTL. A trace holds every read value (or Z), every IRQ 2
change, the observed value at every expectation point (registers and plane
bytes through the side-effect-free debug port), full 256 KB plane dumps at
the end of every random seed, and the complete dot stream (six colour bits,
both retraces, blank, display enable, driver enable). Independently of the
model, the BIOS mode-table geometry is checked against TR's mode tables and
display figures, and three BIOS replays are checked pixel for pixel against
screens rebuilt from the ROM's own font and parameter table.

All commands ran in `ai-hw-engineer:latest` (Verilator 5.052, Yosys 0.69,
SBY with abc pdr and yices, Python 3.14.4):

```sh
sh design/ibm_ega/scripts/run_all.sh
```

| Gate | Command | Result |
|---|---|---|
| ROM | `scripts/get_rom.py` | 86Box dump SHA-256 `bf1583dd...dbbf9c`, SHA-1 `3af56105...6b25`, CRC32 `2f2fbc40`; reversed (EPROM order) = MAME `6277356.u44` CRC `dc146448`; header 55 AA 20, checksum 00; sign-on and VIDEO_PARMS entry 0 equal the zoomed listing |
| Lint | `scripts/run_lint.sh` | `verilator --lint-only -Wall` clean for `ibm_ega` and for each of the 9 sub-modules alone; no waivers (1 s) |
| Formal | `scripts/run_formal.sh` | abc pdr PASS (unbounded) for the graphics controller, the CRTC (horizontal and vertical tasks) and the card top; smtbmc yices covers 5 + 2 + 7 reached (94 s) |
| Directed | `scripts/run_sim.sh` | 40 of 40: the model meets every hand-derived expectation; RTL trace identical |
| Random | `scripts/run_sim.sh` | 32 seeds x 600 operations: 37,828 trace lines and 1,401,555 dots identical, plus 32 x 256 KB plane dumps |
| BIOS mode tables | `scripts/bios_modes.py` | all 23 VIDEO_PARMS entries identical RTL/model; line and frame lengths equal the registers; displayed area equals TR p.5-7 for every documented mode; rates within 2% of TR's display figures (table below) |
| BIOS replay | `scripts/bios_replay.py` | modes 3 (640x200), 3* (640x350) and 7 (720x350): every displayed pixel equals the screen rebuilt from the ROM font and table; switch reads assemble INFO_3 = 7, 9, B as listing lines 584-596 expect |
| Coverage gate | `scripts/report_coverage.py --require` | PASS: 61 registers written, all 770 documented register-bit values written as 0 and 1, every write/read mode, read map select 0-7, memory map x odd/even, chain variants, skews, panning 1-15, CRTC features, all 23 BIOS entries |
| Mutation | `scripts/run_mutation.sh` | 15 of 15 mutants killed by a trace difference (90 s) |
| Synthesis | `scripts/run_synth.sh` | Yosys `synth -flatten`, `check -assert` clean, 5,845 generic cells, 845 flip-flops; the 4 plane RAMs and the ROM are black boxes; no `Latch inferred` (276 s) |
| Whole flow | `scripts/run_all.sh` | PASS in 572 s from a clean work directory (`work/refs`, `work/firmware` kept) |

## BIOS mode-table geometry

Measured from the RTL dot stream (identical to the model's). "vs TR" compares
the line and frame rates with the display figures on TR p.6-7.

| Entry | Mode | Dot clock MHz | Characters x dots = dots/line | Lines/frame | HSYNC | VSYNC lines | Displayed | Line rate | Frame rate | vs TR display |
|---|---|---|---|---|---|---|---|---|---|---|
| 00 | mode 0, 40x25 A/N | 14.31818 /2 | 57 x 8 = 456 | 262 | 32 dots | 3 | 320 x 200 | 15.70 kHz | 59.92 Hz | color 15.75 kHz / 60 Hz: -0.3% / -0.1% |
| 01 | mode 1, 40x25 A/N | 14.31818 /2 | 57 x 8 = 456 | 262 | 32 dots | 3 | 320 x 200 | 15.70 kHz | 59.92 Hz | color 15.75 kHz / 60 Hz: -0.3% / -0.1% |
| 02 | mode 2, 80x25 A/N | 14.31818 | 114 x 8 = 912 | 262 | 64 dots | 3 | 640 x 200 | 15.70 kHz | 59.92 Hz | color 15.75 kHz / 60 Hz: -0.3% / -0.1% |
| 03 | mode 3, 80x25 A/N | 14.31818 | 114 x 8 = 912 | 262 | 64 dots | 3 | 640 x 200 | 15.70 kHz | 59.92 Hz | color 15.75 kHz / 60 Hz: -0.3% / -0.1% |
| 04 | mode 4, 320x200 4 colours | 14.31818 /2 | 57 x 8 = 456 | 262 | 32 dots | 3 | 320 x 200 | 15.70 kHz | 59.92 Hz | color 15.75 kHz / 60 Hz: -0.3% / -0.1% |
| 05 | mode 5, 320x200 4 colours | 14.31818 /2 | 57 x 8 = 456 | 262 | 32 dots | 3 | 320 x 200 | 15.70 kHz | 59.92 Hz | color 15.75 kHz / 60 Hz: -0.3% / -0.1% |
| 06 | mode 6, 640x200 2 colours | 14.31818 | 114 x 8 = 912 | 262 | 64 dots | 3 | 640 x 200 | 15.70 kHz | 59.92 Hz | color 15.75 kHz / 60 Hz: -0.3% / -0.1% |
| 07 | mode 7, 80x25 monochrome A/N | 16.25700 | 98 x 9 = 882 | 370 | 135 dots | 16 | 720 x 350 | 18.43 kHz | 49.82 Hz | mono 18.43 kHz / 50 Hz: +0.0% / -0.4% |
| 08 | reserved entry 8 | 14.31818 | 57 x 9 = 513 | 262 | 36 dots | 3 | 360 x 200 | 27.91 kHz | 106.53 Hz | (not a display mode in TR) |
| 09 | reserved entry 9 | 14.31818 | 57 x 9 = 513 | 262 | 36 dots | 3 | 360 x 200 | 27.91 kHz | 106.53 Hz | (not a display mode in TR) |
| 0A | reserved entry A | 14.31818 | 57 x 9 = 513 | 262 | 36 dots | 3 | 360 x 200 | 27.91 kHz | 106.53 Hz | (not a display mode in TR) |
| 0B | font-load set (colour) | 14.31818 | 114 x 8 = 912 | 262 | 64 dots | 3 | 640 x 200 | 15.70 kHz | 59.92 Hz | (not a display mode in TR) |
| 0C | font-load set (monochrome) | 16.25700 | 98 x 9 = 882 | 370 | 135 dots | 16 | 720 x 350 | 18.43 kHz | 49.82 Hz | (not a display mode in TR) |
| 0D | mode D, 320x200 16 colours | 14.31818 /2 | 57 x 8 = 456 | 262 | 32 dots | 3 | 320 x 200 | 15.70 kHz | 59.92 Hz | color 15.75 kHz / 60 Hz: -0.3% / -0.1% |
| 0E | mode E, 640x200 16 colours | 14.31818 | 114 x 8 = 912 | 262 | 64 dots | 3 | 640 x 200 | 15.70 kHz | 59.92 Hz | color 15.75 kHz / 60 Hz: -0.3% / -0.1% |
| 0F | mode F, 640x350 mono graphics (64 KB) | 14.31818 | 98 x 8 = 784 | 370 | 128 dots | 16 | 640 x 350 | 18.26 kHz | 49.36 Hz | mono 18.43 kHz / 50 Hz: -0.9% / -1.3% |
| 10 | mode 10, 640x350 (64 KB) | 16.25700 | 93 x 8 = 744 | 366 | 80 dots | 13 | 640 x 350 | 21.85 kHz | 59.70 Hz | enhanced 21.85 kHz / 60 Hz: +0.0% / -0.5% |
| 11 | mode F, 640x350 mono graphics (>64 KB) | 14.31818 | 98 x 8 = 784 | 370 | 128 dots | 16 | 640 x 350 | 18.26 kHz | 49.36 Hz | mono 18.43 kHz / 50 Hz: -0.9% / -1.3% |
| 12 | mode 10, 640x350 16/64 colours (>64 KB) | 16.25700 | 93 x 8 = 744 | 366 | 88 dots | 13 | 640 x 350 | 21.85 kHz | 59.70 Hz | enhanced 21.85 kHz / 60 Hz: +0.0% / -0.5% |
| 13 | mode 0*, 40x25 A/N enhanced | 16.25700 /2 | 47 x 8 = 376 | 366 | 40 dots | 13 | 320 x 350 | 21.62 kHz | 59.07 Hz | enhanced 21.85 kHz / 60 Hz: -1.1% / -1.6% |
| 14 | mode 1*, 40x25 A/N enhanced | 16.25700 /2 | 47 x 8 = 376 | 366 | 40 dots | 13 | 320 x 350 | 21.62 kHz | 59.07 Hz | enhanced 21.85 kHz / 60 Hz: -1.1% / -1.6% |
| 15 | mode 2*, 80x25 A/N enhanced | 16.25700 | 93 x 8 = 744 | 366 | 80 dots | 13 | 640 x 350 | 21.85 kHz | 59.70 Hz | enhanced 21.85 kHz / 60 Hz: +0.0% / -0.5% |
| 16 | mode 3*, 80x25 A/N enhanced | 16.25700 | 93 x 8 = 744 | 366 | 80 dots | 13 | 640 x 350 | 21.85 kHz | 59.70 Hz | enhanced 21.85 kHz / 60 Hz: +0.0% / -0.5% |

IBM's own register values put mode F (14.318 MHz with 784-dot lines) and the
enhanced 40-column modes 0*/1* (376-dot lines) 0.9-1.6% below the nominal
monitor figures; all other documented modes are within 0.5%. Entries 8-0Ah
are reserved and 0Bh/0Ch are the font-load register sets.

## Independence of the reference model

The model, the directed expectations and the BIOS checks were derived from
TR (register text, mode tables, logic diagrams, BIOS listing and the ROM
code). Behaviour TR leaves open is tagged E1-E33 in the spec with the same
tags in the RTL and model. While writing the directed tests, expectations
first disagreed with the model in 21 places; all were traced to errors in
the hand derivation or the test scripts (hexadecimal vs decimal dot indices,
the bit mask's power-on value 0, the last ROM byte, 9-dot panning value 8 =
no shift, the cursor taking the character's foreground, scripts that never
started the sequencer), not to the model.

A first mutation run showed that XREG/XMEM expectations were checked on the
model only, so a write-path fault survived. Both traces now carry the
observed value at every expectation and full plane dumps; afterwards every
mutant was killed.

## Mutation check

| Mutant | Fault | First failing test |
|---|---|---|
| m1 | function AND acts as OR | `write_mode0` |
| m2 | bit mask ignored | `write_mode0` |
| m3 | set/reset value taken from the enable bit | `write_mode0` |
| m4 | colour compare inverted | `read_modes` |
| m5 | odd/even read ignores A0 | `odd_even_and_chain` |
| m6 | horizontal total + 3 characters | `tiny_frame_timing` |
| m7 | vertical retrace end compared on 5 bits | `vertical_interrupt` |
| m8 | line compare restarts at the start address | `split_screen` |
| m9 | blink enable keeps background bit 3 | `text_attributes_blink` |
| m10 | colour plane enable not applied | `graphics_pixels` |
| m11 | 9-dot panning without the 8,0,1,.. order | `text_nine_dot_and_line_graphics` |
| m12 | A10 decoded (no 400h aliases) | `io_decode_aliases` |
| m13 | Input Status 1 also at 3xB | `io_decode_aliases` |
| m14 | odd/even write plane select inverted | `odd_even_and_chain` |
| m15 | attribute writes to 3C1 dropped (the escaped defect) | `bios_dot_test_attribute_writes` |

The proofs are not vacuous: with a function-select fault the graphics
controller proof fails, with m7 the CRTC vertical proof fails, and with the
map mask removed from the plane write enable the card-top proof fails.

## Escaped defect: attribute writes to 3C1 (2026-11-16)

Running the unchanged EGA BIOS on the 80286 of the IBM PC AT system model,
the POST dot test failed (BL = 10h): the BIOS's OUT_DX helper writes the
attribute index to 3C0 and the data to 3C1 (C000:0403-0416), and the decode
accepted only 3C0. The model shared the assumption (E3 read "exactly the TR
ports"), and the BIOS replay had run SET_REGS (which writes 3C0 twice) but
not the self tests that use the helper. Fixed in `ega_io_decode.sv` and the
model; E3 now cites the BIOS. Regression: directed test
`bios_dot_test_attribute_writes` (the dot test's exact port sequence),
coverage item `attr_write_3c1`, mutant m15. A byte scan of every
`CALL 0D15h` in the ROM shows OUT_DX is otherwise used only with DX = 3C4,
3CE and the CRTC base 3B4/3D4, whose DX+1 ports are decoded. Post-mortem:
[failure_notes/2026-11-16-ibm-ega-attribute-3c1.md](../../../failure_notes/2026-11-16-ibm-ega-attribute-3c1.md).

## Findings in the sources

- **ROM byte order.** The EGA's EPROM address pins are driven by inverted
  address lines (sheets 1 and 4), so a programmer dump is the CPU image
  reversed. MAME stores the chip dump and reverses it at load; 86Box's file
  is in CPU order. Both are the same 16 KB.
- **TR vs the wiring and IBM's VGA reference.** TR p.15 says Input Status 0
  bit 7 = 1 while video is displayed, but CRTINT is wired straight to IRQ 2
  (active high) and to that bit (E9). TR p.16 says Input Status 1 bit 0 = 0
  in retrace; the VGA reference and the EGA BIOS's own CGA-style polling
  (C000:1719) use 1 (E10). TR p.54 says Color Don't Care 1 = don't care; the
  VGA reference says 1 = compared and the BIOS loads 0Fh in graphics modes
  (E15). TR p.60 misprints the panning register index as 12h. TR p.56 names
  only 3C0 for the attribute controller; the BIOS also writes it at 3C1 (E3).
- **Switch numbering.** The BIOS (C000:009B) puts the reading taken with
  clock select 00 into INFO_3 bit 3, which TR p.15 calls switch 4 (E31);
  that differs from the usual DIP pin numbering of SW1 on sheet 9.
- **Emulators.** MAME follows TR's text for ISR0 bit 7, uses VT + 1 lines
  and swaps the video status mux pairs for settings 01 and 10 relative to
  TR's table; 86Box toggles status bits to pass the BIOS self test, uses
  1 = compare for Color Don't Care and VT + 2 lines. MAME handles
  attribute writes only at 3C0; 86Box accepts 3C0 and 3C1. See the spec table.

## Limitations

- 256 KB only; 64 KB and 128 KB are not modeled (their BIOS entries are
  only checked for geometry).
- No CPU wait states (I/O CH RDY never driven), no DRAM refresh or
  CPU/display cycle interleaving; the bandwidth bit, CRTC output control and
  GC test condition have no effect (E26).
- The feature connector is not modeled beyond FEAT0/1 and FC0/1.
- Pipeline depths (E18), cursor/underline row conventions (E16), blink
  rates (E23), shift-load serialisation (E19) and the RESET DRV effect on
  the CRTC (E2) are assumptions; the BIOS checks validate them only for the
  values the BIOS programs.
- The bench never overlaps bus operations with dots (the model's time is
  atomic). The BIOS replay covers VIDEO_SETUP's switch and feature reads,
  the font load and the mode set; it does not execute the BIOS on an x86
  model (the POST memory and display self tests are not replayed). That
  happens when the card is integrated into `system/ibm_pc_at_5170`.
- Formal bounds: the CRTC retrace-width proofs assume HT <= 48
  (horizontal), or HT <= 2 and VT <= 30 (vertical), retraces that do not
  wrap the line or frame, and no HRTC/2; the card-top proof assumes ISA
  strobe discipline (one strobe at a time, stable address).
